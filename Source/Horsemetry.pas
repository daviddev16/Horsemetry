unit Horsemetry;

interface

{$R html.res}

uses
  Horse,
  Horsemetry.DataStore,
  Horsemetry.BackgroundWorker;

type
  THorsemetryContext = class sealed
    strict private
      class threadvar ContextId: String;
    public
      class function GetContextId(): String;
      class procedure SetContextId(const Value: String);
      class procedure ClearContext();
    end;

  THorsemetry = class sealed
    strict private
      // lock for the Worker thread instance
      class var _Lock: TObject;
      // lock for FDataStoreProviderClass
      class var _DspLock: TObject;
      class var FDataStoreProviderClass: TClass;
      class var FWorker: TBackgroundWorker;
    public
      class procedure StartCapture();
      class procedure StopCature();
      class procedure SetDataStoreProviderClass(const Clazz: TClass);
      class function NewDataStore(): IDataStore;
      class procedure PushSubRoutine(const Name: String; const DurationMillis: Integer);
      class procedure InstallRoutes();
    protected
      class constructor Initialize();
      class destructor Unitialize();
    end;


//
// Horse middleware.
//
procedure Telemetry(
  Request: THorseRequest;
  Response: THorseResponse;
  Next: TNextProc);

implementation

uses
  System.Classes,
  System.Types,
  System.SysUtils,
  System.Diagnostics,
  System.JSON.Serializers,
  Horsemetry.Utils,
  Horsemetry.Command.Types,
  Horsemetry.Command.Queue,
  Horsemetry.Command.Serializer,
  Horsemetry.DTO.Statistics,
  Horsemetry.DTO.SubRoutine;

{$REGION 'Horse Middleware'}

procedure Telemetry(
  Request: THorseRequest;
  Response: THorseResponse;
  Next: TNextProc);
const
  BLACKLIST: TArray<String> = [
    '/telemetry',
    '/com.chrome.devtools.json'];
var
  lStopwatch: TStopwatch;
  lCommand: TNewRequestDataCommand;
  lResource: String;
begin
  lResource := Request.PathInfo;

  for var SkipResource in BLACKLIST do
  begin
    if Pos(SkipResource, lResource) > 0 then
    begin
      THorsemetryContext.ClearContext();

      if @Next <> nil then
        Next();

      Exit;
    end;
  end;

  THorsemetryContext.SetContextId(THMUtil.NewUUID());
  lStopwatch := TStopwatch.StartNew();
  try
    if @Next <> nil then
      Next();
  finally
    lStopwatch.Stop();
    try
      lCommand.Resource       := lResource;
      lCommand.ContextId      := THorsemetryContext.GetContextId();
      lCommand.DurationMillis := lStopwatch.ElapsedMilliseconds;
      lCommand.CreatedAt      := Now();
      lCommand.StatusCode     := Response.Status;
      lCommand.ResponseBody   := EmptyStr;
      lCommand.Method         := THMUtil.MethodTypeToString(Request.MethodType);
      lCommand.Queries        := Request.RawWebRequest.Query;

      if (lCommand.StatusCode >= 500) and (lCommand.StatusCode < 600) then
        lCommand.ResponseBody := Response.RawWebResponse.Content;

      TCommandQueue.Push(TCommandSerializer.Write(lCommand));
    finally
      THorsemetryContext.ClearContext();
    end;
  end;
end;

{$ENDREGION 'Horse Middleware'}

{ THorsemetry }

class constructor THorsemetry.Initialize();
begin
  FWorker := nil;
  _Lock := TObject.Create();
  _DspLock := TObject.Create();
end;

class procedure THorsemetry.StartCapture();
begin
  TMonitor.Enter(_Lock);
  try
    if Assigned(FWorker) then
      Exit;
    FWorker := TBackgroundWorker.Create();
  finally
    TMonitor.Exit(_Lock);
  end;
end;

class procedure THorsemetry.StopCature();
begin
  TMonitor.Enter(_Lock);
  try
    if not Assigned(FWorker) then
      Exit;
    FWorker.Terminate();
    FWorker.WaitFor();
    FreeAndNil(FWorker);
  finally
    TMonitor.Exit(_Lock);
  end;
end;

class procedure THorsemetry.SetDataStoreProviderClass(
  const Clazz: TClass);
begin
  TMonitor.Enter(_DspLock);
  try
    FDataStoreProviderClass := Clazz;
  finally
    TMonitor.Exit(_DspLock);
  end;
end;

class function THorsemetry.NewDataStore(): IDataStore;
var
  lProviderInstance: TObject;
  lDataStoreProvider: IDataStoreProvider;
begin
  Result := nil;
  TMonitor.Enter(_DspLock);
  try
    lProviderInstance := FDataStoreProviderClass.Create();
    try
      if Supports(lProviderInstance, IDataStoreProvider, lDataStoreProvider) then
        Result := lDataStoreProvider.NewDataStore();
    finally
      lDataStoreProvider := nil;
    end;
  finally
    TMonitor.Exit(_DspLock);
  end;
end;

class procedure THorsemetry.PushSubRoutine(
  const Name: String;
  const DurationMillis: Integer);
var
  lCommand: TNewSubRoutineDataCommand;
begin
  lCommand.Routine := Name;
  lCommand.Parameters := EmptyStr;
  lCommand.DurationMillis := DurationMillis;
  lCommand.ContextId := THorsemetryContext.GetContextId();
  TCommandQueue.Push(TCommandSerializer.Write(lCommand));
end;

class procedure THorsemetry.InstallRoutes();
begin
  THorse.Get(
    '/telemetry' ,
    procedure(Request: THorseRequest; Response: THorseResponse)
    var
      lStream: TResourceStream;
      lStringStream: TStringStream;
    begin
      lStream := TResourceStream.Create(HInstance, 'HTML_INDEX', RT_RCDATA);
      lStringStream := TStringStream.Create('', TEncoding.UTF8);
      try
        lStringStream.CopyFrom(lStream, 0, lStream.Size);
        Response.Send(lStringStream.DataString);
      finally
        lStringStream.Free();
        lStream.Free();
      end;
    end);

  THorse.Get(
    '/telemetry/summary-statistics',
    procedure(Request: THorseRequest; Response: THorseResponse)
    var
      lDataStore: IDataStore;
      lStatistics: TStatistics;
    begin
      lDataStore := THorsemetry.NewDataStore();
      try
        lDataStore.GetStatistics(lStatistics);

        Response
          .Status(THTTPStatus.OK)
          .ContentType('application/json')
          .Send(THMUtil.DTOToString(lStatistics));
      finally
        lDataStore := nil;
      end;
    end);

  THorse.Get(
    '/telemetry/requests',
    procedure(Request: THorseRequest; Response: THorseResponse)
    var
      lDataStore: IDataStore;
      lResourceList: TResourceList;
      lPage: Integer;
      lPageStr: string;
    begin
      lPage := 1;
      if Request.Query.TryGetValue('page', lPageStr) then
        lPage := StrToIntDef(lPageStr, 1);

      lDataStore := THorsemetry.NewDataStore();
      try
        lDataStore.GetResources(lResourceList, lPage);

        Response
          .Status(THTTPStatus.OK)
          .ContentType('application/json')
          .Send(THMUtil.DTOToString(lResourceList));
      finally
        lDataStore := nil;
      end;
    end);

  THorse.Get(
    '/telemetry/subroutine/:ContextId',
    procedure(Request: THorseRequest; Response: THorseResponse)
    var
      lDataStore: IDataStore;
      lContextId: String;
      lSubRoutineList: TSubRoutineList;
    begin
      lContextId := Request.Params.Field('ContextId').Required(True).AsString;
      lDataStore := THorsemetry.NewDataStore();
      try
        lDataStore.GetAllSubRoutinesByContextId(lContextId, lSubRoutineList);

        Response
          .Status(THTTPStatus.OK)
          .ContentType('application/json')
          .Send(THMUtil.DTOToString(lSubRoutineList));
      finally
        lDataStore := nil;
      end;
    end);
end;

class destructor THorsemetry.Unitialize();
begin
  StopCature();
  FreeAndNil(_Lock);
  FreeAndNil(_DspLock);
end;

{ THorsemetryContext }

class procedure THorsemetryContext.ClearContext();
begin
  ContextId := EmptyStr;
end;

class function THorsemetryContext.GetContextId(): String;
begin
  Result := ContextId;
end;

class procedure THorsemetryContext.SetContextId(const Value: String);
begin
  ContextId := Value;
end;

end.

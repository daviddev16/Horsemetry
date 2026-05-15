unit Horsemetry;

interface

{$R html.res}

uses
  Horse,
  Horsemetry.DataStore,
  Horsemetry.BackgroundWorker,
  System.Generics.Collections;

type
  THorsemetryContextData = record
    public
      ContextId: String;
      ResponseBody: String;
      ResponseStatusCode: Integer;
    end;

  THorsemetryContext = class sealed
    strict private
      class threadvar Data: THorsemetryContextData;
    public
      class function GetContextId(): String;
      class procedure SetContextId(const Value: String);

      class function GetResponseBody(): String;
      class procedure SetResponseBody(const Value: String);

      class function GetResponseStatusCode(): Integer;
      class procedure SetResponseStatusCode(const Value: Integer);

      class procedure ClearContext();
    end;

  THorsemetryConfiguration = class sealed
    strict private
      _Lock: TObject;
      FConfigMap: TDictionary<String, String>;
      FResourceBlacklist: TThreadList<String>;
    public
      procedure SetConfig(const Key, Value: String);
      function GetConfig(const Key: String; const Default: String = ''): String;
      function IsOnBlacklist(const Resource: String): Boolean;
      procedure AddToBlacklist(const Resource: String);
      procedure ReplaceWith(var Content: String; const Placeholder, Key: String; const Default: String = '');
    public
      constructor Create();
      destructor Destroy(); override;
    end;

  THorsemetry = class sealed
    type
      Pages = class
        class var MainPageHTMLCache: String;
      end;
    strict private
      // lock for the Worker thread instance
      class var _Lock: TObject;
      // lock for FDataStoreProviderClass
      class var _DspLock: TObject;
      class var FDataStoreProviderClass: TClass;
      class var FWorker: TBackgroundWorker;
      class var FConfiguration: THorsemetryConfiguration;
    private
      class function GetMainPageHTML(): String;
    public
      class procedure StartCapture();
      class procedure StopCapture();
      class procedure SetHeader(const Value: String);
      class procedure SetDescription(const Value: String);
      class procedure IgnoreResource(const Value: String);
      class function IsResourceIgnored(const Value: String): Boolean;
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
  Horsemetry.DTO.SubRoutine,
  Horsemetry.DataStore.Filter;

{$REGION 'Horse Middleware'}

procedure Telemetry(
  Request: THorseRequest;
  Response: THorseResponse;
  Next: TNextProc);
var
  lStopwatch: TStopwatch;
  lCommand: TNewRequestDataCommand;
  lResource: String;
begin
  lResource := Request.PathInfo;

  if THorsemetry.IsResourceIgnored(lResource) then
  begin
    if @Next <> nil then
      Next();
    Exit;
  end;

  THorsemetryContext.SetContextId(THMUtil.NewUUID());
  lStopwatch := TStopwatch.StartNew();
  try
    if @Next <> nil then
      Next();
  finally
    lStopwatch.Stop();
    try
      THorsemetryContext.SetResponseStatusCode(Response.Status);

      if String.IsNullOrWhitespace(THorsemetryContext.GetResponseBody()) then
        THorsemetryContext.SetResponseBody(Response.RawWebResponse.Content);

      lCommand.Resource       := lResource;
      lCommand.ContextId      := THorsemetryContext.GetContextId();
      lCommand.DurationMillis := lStopwatch.ElapsedMilliseconds;
      lCommand.ResponseBody   := THorsemetryContext.GetResponseBody();
      lCommand.StatusCode     := THorsemetryContext.GetResponseStatusCode();
      lCommand.Method         := THMUtil.MethodTypeToString(Request.MethodType);
      lCommand.Queries        := Request.RawWebRequest.Query;
      lCommand.CreatedAt      := Now();

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

class function THorsemetry.GetMainPageHTML(): String;
var
  lStream: TResourceStream;
  lStringStream: TStringStream;
  lContent: String;
begin
  lContent := Pages.MainPageHTMLCache;

  if not lContent.IsEmpty then
  begin
    Result := lContent;
    Exit;
  end;

  TMonitor.Enter(_Lock);
  try
    lStream := TResourceStream.Create(HInstance, 'HTML_INDEX', RT_RCDATA);
    lStringStream := TStringStream.Create('', TEncoding.UTF8);
    try
      lStringStream.CopyFrom(lStream, 0, lStream.Size);
      lContent := lStringStream.DataString;

      FConfiguration.ReplaceWith(
        lContent,
        '${[{PLACEHOLDER_HEADER}]}',
        'Header',
        'Horsemetry');

      FConfiguration.ReplaceWith(
        lContent,
        '${[{PLACEHOLDER_DESCRIPTION}]}',
        'Description',
        'API Observability & Telemetry Dashboard');

      Pages.MainPageHTMLCache := lContent;
      Result := Pages.MainPageHTMLCache;
    finally
      lStringStream.Free();
      lStream.Free();
    end;
  finally
    TMonitor.Exit(_Lock);
  end;
end;

class procedure THorsemetry.IgnoreResource(
  const Value: String);
begin
  FConfiguration.AddToBlacklist(Value);
end;

class function THorsemetry.IsResourceIgnored(
  const Value: String): Boolean;
begin
  Result := FConfiguration.IsOnBlacklist(Value);
end;

class constructor THorsemetry.Initialize();
begin
  FWorker := nil;

  FConfiguration := THorsemetryConfiguration.Create();
  FConfiguration.AddToBlacklist('/telemetry');
  FConfiguration.AddToBlacklist('/com.chrome.devtools.json');

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

class procedure THorsemetry.StopCapture();
begin
  TMonitor.Enter(_Lock);
  try
    if not Assigned(FWorker) then
      Exit;
    FWorker.Terminate();
    TCommandQueue.Shutdown();
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

class procedure THorsemetry.SetDescription(const Value: String);
begin
  FConfiguration.SetConfig('Description', Value);
end;

class procedure THorsemetry.SetHeader(const Value: String);
begin
  FConfiguration.SetConfig('Header', Value);
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
    begin
      Response
        .Status(THTTPStatus.OK)
        .ContentType('text/html; charset=UTF-8')
        .Send(GetMainPageHTML());
    end);

  THorse.Get(
    '/telemetry/summary-statistics',
    procedure(Request: THorseRequest; Response: THorseResponse)
    var
      lDataStore: IDataStore;
      lStatistics: TStatistics;
      lFilter: TDataStoreFilter;
    begin
      lFilter := THMUtil.ParseFilter(Request);
      lDataStore := THorsemetry.NewDataStore();
      try
        lDataStore.GetStatistics(lStatistics, lFilter);

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
      lFilter: TDataStoreFilter;
    begin
      lFilter := THMUtil.ParseFilter(Request);
      lDataStore := THorsemetry.NewDataStore();
      try
        lDataStore.GetResources(lResourceList, lFilter);

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
      lSubRoutineList: TSubRoutineList;
      lFilter: TDataStoreFilter;
    begin
      lFilter := TDataStoreFilter.New();
      lFilter.ContextId := Request.Params.Field('ContextId').Required(True).AsString;

      lDataStore := THorsemetry.NewDataStore();
      try
        lDataStore.GetAllSubRoutinesByContextId(lSubRoutineList, lFilter);

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
  StopCapture();
  FreeAndNil(FConfiguration);
  FreeAndNil(_Lock);
  FreeAndNil(_DspLock);
end;

{ THorsemetryContext }

class procedure THorsemetryContext.ClearContext();
begin
  Data := Default(THorsemetryContextData);
end;

class function THorsemetryContext.GetContextId(): String;
begin
  Result := Data.ContextId;
end;

class function THorsemetryContext.GetResponseBody(): String;
begin
  Result := Data.ResponseBody;
end;

class function THorsemetryContext.GetResponseStatusCode(): Integer;
begin
  Result := Data.ResponseStatusCode;
end;

class procedure THorsemetryContext.SetContextId(const Value: String);
begin
  Data.ContextId := Value;
end;

class procedure THorsemetryContext.SetResponseBody(const Value: String);
begin
  Data.ResponseBody := Value;
end;

class procedure THorsemetryContext.SetResponseStatusCode(const Value: Integer);
begin
  Data.ResponseStatusCode := Value;
end;

{ THorsemetryConfiguration }

procedure THorsemetryConfiguration.AddToBlacklist(const Resource: String);
begin
  FResourceBlacklist.Add(Resource);
end;

constructor THorsemetryConfiguration.Create();
begin
  _Lock := TObject.Create();
  FResourceBlacklist := TThreadList<String>.Create();
  FConfigMap := TDictionary<String, String>.Create();
end;

function THorsemetryConfiguration.GetConfig(
  const Key: String;
  const Default: String): String;
begin
  TMonitor.Enter(_Lock);
  try
    if not FConfigMap.TryGetValue(Key, Result) then
      Result := Default;
  finally
    TMonitor.Exit(_Lock);
  end;
end;

function THorsemetryConfiguration.IsOnBlacklist(
  const Resource: String): Boolean;
var
  lBlacklist: TList<String>;
begin
  lBlacklist := FResourceBlacklist.LockList;
  try
    for var BlacklistResource in lBlacklist do
    begin
      if Resource.StartsWith(BlacklistResource, True) then
      begin
        Result := True;
        Exit;
      end;
    end;
    Result := False;
  finally
    FResourceBlacklist.UnlockList;
  end;
end;

procedure THorsemetryConfiguration.ReplaceWith(
  var Content: String;
  const Placeholder, Key, Default: String);
begin
  Content := Content.Replace(Placeholder, GetConfig(Key, Default), []);
end;

procedure THorsemetryConfiguration.SetConfig(const Key, Value: String);
begin
  TMonitor.Enter(_Lock);
  try
    FConfigMap.AddOrSetValue(Key, Value);
  finally
    TMonitor.Exit(_Lock);
  end;
end;

destructor THorsemetryConfiguration.Destroy();
begin
  TMonitor.Enter(_Lock);
  try
    FConfigMap.Free();
  finally
    TMonitor.Exit(_Lock);
  end;
  FResourceBlacklist.Free();
  inherited;
end;

end.

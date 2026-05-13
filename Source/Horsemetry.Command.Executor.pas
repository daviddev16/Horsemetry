unit Horsemetry.Command.Executor;

interface

uses
  System.JSON,
  System.TypInfo,
  System.SysUtils,
  Horsemetry.DataStore,
  Horsemetry.Command.Types,
  Horsemetry.Command.Serializer;

type
  TCommandExecutor = class
    strict private
      FDataStore: IDataStore;
    private
      procedure ExecuteCommand(const Command: TNewRequestDataCommand); overload;
      procedure ExecuteCommand(const Command: TNewSubRoutineDataCommand); overload;
    public
      constructor Create(DataStore: IDataStore);
      procedure Execute(const JSONCommand: String);
    end;

implementation

uses
  Horsemetry;

{ TCommandExecutor }

constructor TCommandExecutor.Create(DataStore: IDataStore);
begin
  FDataStore := DataStore;
end;

procedure TCommandExecutor.Execute(const JSONCommand: String);
var
  lJSONValue: TJSONValue;
  lCommandTypeInfo: PTypeInfo;
begin
  lJSONValue := TJSONValue.ParseJSONValue(JSONCommand);
  try
    lCommandTypeInfo := TCommandSerializer.GetCommandTypeInfo(lJSONValue);

    if lCommandTypeInfo = nil then
      Exit;

    if lCommandTypeInfo = TypeInfo(TNewRequestDataCommand) then
      ExecuteCommand(TCommandSerializer.Read<TNewRequestDataCommand>(lJSONValue))

    else if lCommandTypeInfo = TypeInfo(TNewSubRoutineDataCommand) then
      ExecuteCommand(TCommandSerializer.Read<TNewSubRoutineDataCommand>(lJSONValue));
  finally
    lJSONValue.Free();
  end;
end;

procedure TCommandExecutor.ExecuteCommand(const Command: TNewSubRoutineDataCommand);
begin
  if FDataStore = nil then
    Exit;
  FDataStore.PersistSubRoutine(Command);
end;

procedure TCommandExecutor.ExecuteCommand(const Command: TNewRequestDataCommand);
begin
  if FDataStore = nil then
    Exit;
  FDataStore.PersistRequest(Command);
end;

end.

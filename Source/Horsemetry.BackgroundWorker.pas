unit Horsemetry.BackgroundWorker;

interface

uses
  System.Types,
  System.Classes,
  System.SysUtils,
  System.Generics.Collections,
  Horsemetry.DataStore,
  Horsemetry.Command.Queue,
  Horsemetry.Command.Executor;

type
  TBackgroundWorker = class(TThread)
    protected
      procedure Execute(); override;
    end;

implementation

uses
  Horsemetry;

{ TBackgroundWorker }

procedure TBackgroundWorker.Execute();
var
  lJSONCommand: String;
  lDataStore: IDataStore;
  lCommandExecutor: TCommandExecutor;
begin
  lDataStore := THorsemetry.NewDataStore();
  try
    lDataStore.CleanUp();
    lCommandExecutor := TCommandExecutor.Create(lDataStore);
    try
      while not Terminated do
      begin
        while TCommandQueue.Pop(lJSONCommand) do
          lCommandExecutor.Execute(lJSONCommand);
      end;
    finally
      lCommandExecutor.Free();
    end;
  finally
    lDataStore := nil;
  end;
end;

end.

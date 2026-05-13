unit Horsemetry.DataStore;

interface

uses
  Horsemetry.Command.Types,
  Horsemetry.DTO.SubRoutine,
  Horsemetry.DTO.Statistics;

type
  IDataStore = interface
    function GetResources(out Resources: TResourceList; const Page: Integer = 1; const Limit: Integer = 50): Boolean;
    function GetStatistics(out Statistics: TStatistics): Boolean;
    procedure PersistRequest(const Command: TNewRequestDataCommand);
    procedure PersistSubRoutine(const Command: TNewSubRoutineDataCommand);
    procedure GetAllSubRoutinesByContextId(const ContextId: String; var SubRoutineList: TSubRoutineList);
    procedure CleanUp();
  end;

  IDataStoreProvider = interface
    ['{CAE303C7-7883-47D7-BB8D-7267A0D3A3A6}']
    function NewDataStore(): IDataStore;
  end;

implementation

end.

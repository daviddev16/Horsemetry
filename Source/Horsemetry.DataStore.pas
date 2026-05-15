unit Horsemetry.DataStore;

interface

uses
  Horsemetry.Command.Types,
  Horsemetry.DTO.SubRoutine,
  Horsemetry.DTO.Statistics,
  Horsemetry.DataStore.Filter;

type
  IDataStore = interface
    function GetResources(out Resources: TResourceList; const Filter: TDataStoreFilter): Boolean;
    function GetStatistics(out Statistics: TStatistics; const Filter: TDataStoreFilter): Boolean;
    procedure PersistRequest(const Command: TNewRequestDataCommand);
    procedure PersistSubRoutine(const Command: TNewSubRoutineDataCommand);
    procedure GetAllSubRoutinesByContextId(var SubRoutineList: TSubRoutineList; const Filter: TDataStoreFilter);
    procedure CleanUp();
  end;

  IDataStoreProvider = interface
    ['{CAE303C7-7883-47D7-BB8D-7267A0D3A3A6}']
    function NewDataStore(): IDataStore;
  end;

implementation

end.

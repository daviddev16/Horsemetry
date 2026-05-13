unit Horsemetry.DTO.SubRoutine;

interface

type
  TSubRoutine = record
    Name: String;
    DurationMillis: Integer;
    ContextId: String;
  end;

  TSubRoutineList = TArray<TSubRoutine>;

implementation

end.

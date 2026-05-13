unit Horsemetry.Command.Types;

interface

type
  TNewSubRoutineDataCommand = record
    Routine: String;
    Parameters: String;
    DurationMillis: Integer;
    ContextId: String;
  end;

  TNewRequestDataCommand = record
    public
      Resource: String;
      Queries: String;
      Method: String;
      DurationMillis: Integer;
      CreatedAt: TDateTime;
      ContextId: String;
      StatusCode: Integer;
      ResponseBody: String;
    end;

implementation

end.

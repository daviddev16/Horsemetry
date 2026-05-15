unit Horsemetry.DataStore.Filter;

interface

type
  TDataStoreFilter = record
    Page: Integer;
    Limit: Integer;
    StartDate: TDateTime;
    EndDate: TDateTime;
    ContextId: String;
    class function New(): TDataStoreFilter; static;
  end;

implementation

uses
  System.SysUtils;

{ TDataStoreFilter }

class function TDataStoreFilter.New: TDataStoreFilter;
begin
  Result.Page := 1;
  Result.Limit := 50;
  Result.StartDate := 0;
  Result.EndDate := 0;
  Result.ContextId := EmptyStr;
end;

end.

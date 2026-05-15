unit Horsemetry.Utils;

interface

uses
  Horse,
  Web.HTTPApp,
  System.SysUtils,
  Horsemetry.DataStore,
  Horsemetry.DataStore.Filter;

type
  THMUtil = class
    class function NewUUID(): String;
    class function DTOToString<T>(const Data: T): String;
    class function MethodTypeToString(const MethodType: TMethodType): String;
    class function TryParseISODate(const DateStr: String; out Date: TDateTime): Boolean;
    class function ParseFilter(const Request: THorseRequest): TDataStoreFilter;
  end;

implementation

uses
  System.DateUtils,
  System.JSON.Serializers;

class function THMUtil.NewUUID(): String;
var
  lGuid: String;
begin
  lGuid := LowerCase(GUIDToString(TGUID.NewGuid()));
  Result := lGuid.Substring(1, lGuid.Length - 2);
end;

class function THMUtil.DTOToString<T>(
  const Data: T): String;
var
  lJsonSerializer: TJsonSerializer;
begin
  lJsonSerializer := TJsonSerializer.Create();
  try
    Result := lJsonSerializer.Serialize<T>(Data);
  finally
    lJsonSerializer.Free();
  end;
end;

class function THMUtil.MethodTypeToString(
  const MethodType: TMethodType): String;
begin
  case MethodType of
    mtAny: Result := 'ANY';
    mtGet: Result := 'GET';
    mtPut: Result := 'PUT';
    mtPost: Result := 'POST';
    mtHead: Result := 'HEAD';
    mtDelete: Result := 'DELETE';
    mtPatch: Result := 'PATCH';
  end;
end;
class function THMUtil.TryParseISODate(const DateStr: String;
  out Date: TDateTime): Boolean;
begin
  Result := False;
  if DateStr.IsEmpty then
    Exit;
  try
    Date := System.DateUtils.ISO8601ToDate(DateStr);
    Result := True;
  except
    Result := False;
  end;
end;

class function THMUtil.ParseFilter(const Request: THorseRequest): TDataStoreFilter;
var
  lValue: String;
begin
  Result := TDataStoreFilter.New();

  if Request.Query.TryGetValue('page', lValue) then
    Result.Page := StrToIntDef(lValue, 1);

  if Request.Query.TryGetValue('limit', lValue) then
    Result.Limit := StrToIntDef(lValue, 50);

  if Request.Query.TryGetValue('start_date', lValue) then
    TryParseISODate(lValue, Result.StartDate);

  if Request.Query.TryGetValue('end_date', lValue) then
    TryParseISODate(lValue, Result.EndDate);
end;

end.

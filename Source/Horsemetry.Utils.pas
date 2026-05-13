unit Horsemetry.Utils;

interface

uses
  Horse,
  Web.HTTPApp,
  System.SysUtils;

type
  THMUtil = class
    class function NewUUID(): String;
    class function DTOToString<T>(const Data: T): String;
    class function MethodTypeToString(const MethodType: TMethodType): String;
  end;

implementation

uses
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



end.

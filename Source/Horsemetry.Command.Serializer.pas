unit Horsemetry.Command.Serializer;

interface

uses
  System.JSON,
  System.JSON.Serializers,
  System.Rtti,
  System.TypInfo;

type
  TCommandSerializer = class sealed
    public
      class function GetCommandTypeInfo(JsonValue: TJSONValue): PTypeInfo;
      class function Read<T>(JsonValue: TJSONValue): T;
      class function Write<T>(const Command: T): String;
    end;

implementation

{ TCommandSerializer }

class function TCommandSerializer.GetCommandTypeInfo(
  JsonValue: TJSONValue): PTypeInfo;
begin
  Result := PTypeInfo(JsonValue.GetValue<NativeInt>('_TypeInfo', NativeInt(nil)));
end;

class function TCommandSerializer.Read<T>(JsonValue: TJSONValue): T;
var
  lSerializer: TJsonSerializer;
begin
  lSerializer := TJsonSerializer.Create();
  try
    Result := lSerializer.Deserialize<T>(JsonValue.ToJSON());
  finally
    lSerializer.Free();
  end;
end;

class function TCommandSerializer.Write<T>(const Command: T): String;
var
  lData: String;
  lJSONObject: TJSONObject;
  lSerializer: TJsonSerializer;
begin
  lJSONObject := nil;
  lSerializer := TJsonSerializer.Create();
  try
    lData := lSerializer.Serialize<T>(Command);
    lJSONObject := TJSONValue.ParseJSONValue(lData) as TJSONObject;
    lJSONObject.AddPair('_TypeInfo', NativeInt(TypeInfo(T)));
    Result := lJSONObject.ToJSON();
  finally
    lSerializer.Free();
    if Assigned(lJSONObject) then
      lJSONObject.Free();
  end;
end;

end.

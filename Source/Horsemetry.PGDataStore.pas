unit Horsemetry.PGDataStore;

interface

uses
  FireDAC.DApt,
  FireDAC.Stan.Async,
  FireDAC.Phys.PG,
  FireDAC.Stan.Def,
  FireDAC.Stan.Intf,
  FireDAC.Stan.Param,
  FireDAC.Comp.Client,
  Horsemetry.DataStore,
  Horsemetry.DTO.SubRoutine,
  Horsemetry.DTO.Statistics,
  Horsemetry.Command.Types;

type
  TPostgreSQLDataStoreBuilder = record
    strict private
      FSchema: String;
      FServer: String;
      FDatabase: String;
      FPassword: String;
      FUsername: String;
      FVendorLib: String;
    public
      function Schema(const Value: String): TPostgreSQLDataStoreBuilder;
      function Server(const Value: String): TPostgreSQLDataStoreBuilder;
      function Database(const Value: String): TPostgreSQLDataStoreBuilder;
      function Password(const Value: String): TPostgreSQLDataStoreBuilder;
      function Username(const Value: String): TPostgreSQLDataStoreBuilder;
      function VendorLib(const Value: String): TPostgreSQLDataStoreBuilder;
      function Build(): IDataStore;
      class function New(): TPostgreSQLDataStoreBuilder; static;
    end;

  TPostgreSQLDataStore = class(TInterfacedObject, IDataStore)
    strict private
      FSchema: String;
      FConnection: TFDConnection;
      FDriverLink: TFDPhysPgDriverLink;
    private
      procedure GetGlobalStatistics(var Stat: TGlobalStatistics);
      procedure GetStatusCodeSummaryStat(var Stat: TArray<TStatusCodeSummaryStat>);
      procedure GetMethodTypeSummaryStat(var Stat: TArray<TMethodTypeSummaryStat>);
      procedure GetResourceSummaryStat(var Stat: TArray<TResourceSummaryStat>);
      procedure GetTopExpensiveRequests(var Stat: TArray<TResource>);
      procedure GetRequestsPerMinute(var Stat: TArray<TRequestsPerMinuteStat>);
      procedure SetPGSearchPath(const Schema: String);
    public
      function GetResources(out Resources: TResourceList; const Page: Integer = 1; const Limit: Integer = 50): Boolean;
      procedure PersistRequest(const Command: TNewRequestDataCommand);
      procedure PersistSubRoutine(const Command: TNewSubRoutineDataCommand);
      procedure GetAllSubRoutinesByContextId(const ContextId: String; var SubRoutineList: TSubRoutineList);
      function GetStatistics(out Statistics: TStatistics): Boolean;
      procedure CleanUp();
    public
      constructor Create(
          const Schema: String;
          const Server: String;
          const Database: String;
          const Password: String;
          const Username: String;
          const VendorLib: String);

      destructor Destroy(); override;
    end;

implementation

uses
  System.SysUtils;

{ TPostgreSQLDataStore }

constructor TPostgreSQLDataStore.Create(
  const Schema: String;
  const Server: String;
  const Database: String;
  const Password: String;
  const Username: String;
  const VendorLib: String);
begin
  FSchema := Schema;
  FConnection := TFDConnection.Create(nil);
  FDriverLink := TFDPhysPgDriverLink.Create(nil);
  FDriverLink.VendorLib := VendorLib;
  FConnection.Params.Clear();
  FConnection.Params.Add('DriverID=PG');
  FConnection.Params.Add('Port=5432');
  FConnection.Params.Add('Server=' + Server);
  FConnection.Params.Add('Database=' + Database);
  FConnection.Params.Add('User_Name=' + Username);
  FConnection.Params.Add('Password=' + Password);
  FConnection.LoginPrompt := False;
  FConnection.Connected := True;
  if FSchema <> 'public' then
    SetPGSearchPath(FSchema);
end;

procedure TPostgreSQLDataStore.GetAllSubRoutinesByContextId(
  const ContextId: String; var SubRoutineList: TSubRoutineList);
var
  I: Integer;
  lQuery: TFDQuery;
begin
  I := 0;
  lQuery := TFDQuery.Create(nil);
  lQuery.Connection := FConnection;
  try
    lQuery.SQL.Add('SELECT Name, Context_Id, Duration_Millis');
    lQuery.SQL.Add('FROM subroutine');
    lQuery.SQL.Add('WHERE Context_Id = :ContextId');
    lQuery.ParamByName('ContextId').AsString := ContextId;
    lQuery.Open();

    if lQuery.RecordCount = 0 then
      Exit;

    while not lQuery.Eof do
    begin
      SetLength(SubRoutineList, I + 1);
      SubRoutineList[I].Name := lQuery.FieldByName('Name').AsString;
      SubRoutineList[I].ContextId := lQuery.FieldByName('Context_Id').AsString;
      SubRoutineList[I].DurationMillis := lQuery.FieldByName('Duration_Millis').AsInteger;
      Inc(I);
      lQuery.Next();
    end;
  finally
    lQuery.Free();
  end;
end;

procedure TPostgreSQLDataStore.GetGlobalStatistics(
  var Stat: TGlobalStatistics);
var
  lQuery: TFDQuery;
begin
  lQuery := TFDQuery.Create(nil);
  lQuery.Connection := FConnection;
  try
    lQuery.SQL.Add('SELECT');
    lQuery.SQL.Add('  COUNT(DISTINCT context_id) AS UniqueContextsCount,');
    lQuery.SQL.Add('  SUM(CASE WHEN Status_Code >= 400 THEN 1 ELSE 0 END) AS TotalErrors,');
    lQuery.SQL.Add('  SUM(CASE WHEN Status_Code < 400 THEN 1 ELSE 0 END) AS TotalSuccess');
    lQuery.SQL.Add('FROM request;');
    lQuery.Open();

    if lQuery.RecordCount > 0 then
    begin
      Stat.UniqueContextsCount := lQuery.FieldByName('UniqueContextsCount').AsInteger;
      Stat.TotalErrors := lQuery.FieldByName('TotalErrors').AsInteger;
      Stat.TotalSuccess := lQuery.FieldByName('TotalSuccess').AsInteger;
    end
    else
    begin
      Stat.UniqueContextsCount := 0;
      Stat.TotalErrors := 0;
      Stat.TotalSuccess := 0;
    end;
  finally
    lQuery.Free();
  end;
end;

procedure TPostgreSQLDataStore.GetStatusCodeSummaryStat(
  var Stat: TArray<TStatusCodeSummaryStat>);
var
  I: Integer;
  lQuery: TFDQuery;
begin
  I := 0;
  lQuery := TFDQuery.Create(nil);
  lQuery.Connection := FConnection;
  try
    lQuery.SQL.Add('SELECT Status_Code, COUNT(1) AS RequestCount');
    lQuery.SQL.Add('FROM request');
    lQuery.SQL.Add('GROUP BY Status_Code');
    lQuery.SQL.Add('ORDER BY Status_Code;');
    lQuery.Open();

    while not lQuery.Eof do
    begin
      SetLength(Stat, I + 1);
      Stat[I].StatusCode := lQuery.FieldByName('Status_Code').AsInteger;
      Stat[I].RequestCount := lQuery.FieldByName('RequestCount').AsInteger;
      Inc(I);
      lQuery.Next();
    end;
  finally
    lQuery.Free();
  end;
end;

procedure TPostgreSQLDataStore.GetMethodTypeSummaryStat(
  var Stat: TArray<TMethodTypeSummaryStat>);
var
  I: Integer;
  lQuery: TFDQuery;
begin
  I := 0;
  lQuery := TFDQuery.Create(nil);
  lQuery.Connection := FConnection;
  try
    lQuery.SQL.Add('SELECT ');
    lQuery.SQL.Add('	R.Method AS MethodType,');
    lQuery.SQL.Add('	COUNT(1) AS RequestCount,');
    lQuery.SQL.Add('	ROUND(AVG(R.Duration_Millis)) AS AvgDurationMillis,');
    lQuery.SQL.Add('	ROUND(MIN(R.Duration_Millis)) AS MinDurationMillis,');
    lQuery.SQL.Add('	ROUND(MAX(R.Duration_Millis)) AS MaxDurationMillis,');
    lQuery.SQL.Add('	ROUND(CAST(percentile_cont(0.95) WITHIN GROUP (ORDER BY R.Duration_Millis) AS numeric)) AS P95DurationMillis,');
    lQuery.SQL.Add('	ROUND(CAST(percentile_cont(0.99) WITHIN GROUP (ORDER BY R.Duration_Millis) AS numeric)) AS P99DurationMillis,');
    lQuery.SQL.Add('	SUM(CASE WHEN R.Status_Code >= 400 THEN 1 ELSE 0 END) AS ErrorCount');
    lQuery.SQL.Add('FROM request R');
    lQuery.SQL.Add('GROUP BY R.METHOD;');
    lQuery.Open();

    if lQuery.RecordCount = 0 then
      Exit;

    while not lQuery.Eof do
    begin
      SetLength(Stat, I + 1);
      Stat[I].MethodType := lQuery.FieldByName('MethodType').AsString;
      Stat[I].RequestCount := lQuery.FieldByName('RequestCount').AsInteger;
      Stat[I].MinDurationMillis := lQuery.FieldByName('MinDurationMillis').AsInteger;
      Stat[I].MaxDurationMillis := lQuery.FieldByName('MaxDurationMillis').AsInteger;
      Stat[I].AvgDurationMillis := lQuery.FieldByName('AvgDurationMillis').AsInteger;
      Stat[I].P95DurationMillis := lQuery.FieldByName('P95DurationMillis').AsInteger;
      Stat[I].P99DurationMillis := lQuery.FieldByName('P99DurationMillis').AsInteger;
      Stat[I].ErrorCount := lQuery.FieldByName('ErrorCount').AsInteger;
      Inc(I);
      lQuery.Next();
    end;
  finally
    lQuery.Free();
  end;
end;

function TPostgreSQLDataStore.GetResources(
  out Resources: TResourceList;
  const Page: Integer = 1;
  const Limit: Integer = 50): Boolean;
var
  I: Integer;
  lQuery: TFDQuery;
begin
  I := 0;
  lQuery := TFDQuery.Create(nil);
  lQuery.Connection := FConnection;
  try
    lQuery.SQL.Add('SELECT R.*');
    lQuery.SQL.Add('FROM request R');
    lQuery.SQL.Add('ORDER BY R.created_at DESC');
    lQuery.SQL.Add('LIMIT :Limit OFFSET :Offset');
    lQuery.ParamByName('Limit').AsInteger := Limit;
    lQuery.ParamByName('Offset').AsInteger := (Page - 1) * Limit;
    lQuery.Open();

    if lQuery.RecordCount = 0 then
    begin
      Result := False;
      Exit;
    end;

    while not lQuery.Eof do
    begin
      SetLength(Resources, I + 1);
      Resources[I].MethodType := lQuery.FieldByName('Method').AsString;
      Resources[I].Resource := lQuery.FieldByName('Resource').AsString;
      Resources[I].DurationMillis := lQuery.FieldByName('Duration_Millis').AsInteger;
      Resources[I].Queries := lQuery.FieldByName('Queries').AsString;
      Resources[I].ContextId := lQuery.FieldByName('Context_Id').AsString;
      Resources[I].CreateAt := lQuery.FieldByName('Created_At').AsDateTime;
      Resources[I].StatusCode := lQuery.FieldByName('Status_Code').AsInteger;
      Resources[I].ResponseBody := lQuery.FieldByName('Response_Body').AsString;
      Inc(I);
      lQuery.Next();
    end;

    Result := True;
  finally
    lQuery.Free();
  end;
end;

procedure TPostgreSQLDataStore.GetResourceSummaryStat(
  var Stat: TArray<TResourceSummaryStat>);
var
  I: Integer;
  lQuery: TFDQuery;
begin
  I := 0;
  lQuery := TFDQuery.Create(nil);
  lQuery.Connection := FConnection;
  try
    lQuery.SQL.Add('SELECT');
    lQuery.SQL.Add('	R.METHOD,');
    lQuery.SQL.Add('	R.resource,');
    lQuery.SQL.Add('	R.request_count,');
    lQuery.SQL.Add('	ROUND(R.avg_duration_millis) AS avg_duration_millis,');
    lQuery.SQL.Add('	ROUND(R.p95_duration_millis) AS p95_duration_millis,');
    lQuery.SQL.Add('	ROUND(R.p99_duration_millis) AS p99_duration_millis,');
    lQuery.SQL.Add('	R.error_count,');
    lQuery.SQL.Add('	L_J_HEA.Queries AS Heavier_Resource_Queries,');
    lQuery.SQL.Add('	L_J_HEA.Duration_millis AS Heavier_Resource_Duration_Millis,');
    lQuery.SQL.Add('	L_J_HEA.Created_At AS Heavier_Resource_Created_At,');
    lQuery.SQL.Add('	L_J_LIG.Queries AS Lighter_Resource_Queries,');
    lQuery.SQL.Add('	L_J_LIG.Duration_millis AS Lighter_Resource_Duration_Millis,');
    lQuery.SQL.Add('	L_J_LIG.Created_At AS Lighter_Resource_Created_At');
    lQuery.SQL.Add('');
    lQuery.SQL.Add('FROM (');
    lQuery.SQL.Add('	SELECT ');
    lQuery.SQL.Add('		R.METHOD, ');
    lQuery.SQL.Add('		R.Resource,');
    lQuery.SQL.Add('		Count(1) AS request_count, ');
    lQuery.SQL.Add('		Avg(R.Duration_Millis) AS Avg_Duration_Millis,');
    lQuery.SQL.Add('		CAST(percentile_cont(0.95) WITHIN GROUP (ORDER BY R.Duration_Millis) AS numeric) AS p95_duration_millis,');
    lQuery.SQL.Add('		CAST(percentile_cont(0.99) WITHIN GROUP (ORDER BY R.Duration_Millis) AS numeric) AS p99_duration_millis,');
    lQuery.SQL.Add('		SUM(CASE WHEN R.Status_Code >= 400 THEN 1 ELSE 0 END) AS error_count');
    lQuery.SQL.Add('	FROM request R');
    lQuery.SQL.Add('	GROUP BY R.METHOD, R.Resource) R');
    lQuery.SQL.Add('');
    lQuery.SQL.Add('LEFT JOIN LATERAL (');
    lQuery.SQL.Add('	SELECT ');
    lQuery.SQL.Add('		R_0.Queries,');
    lQuery.SQL.Add('		R_0.Duration_Millis, ');
    lQuery.SQL.Add('		R_0.Created_At');
    lQuery.SQL.Add('	FROM request R_0');
    lQuery.SQL.Add('	WHERE (R_0.Resource = R.Resource) AND ');
    lQuery.SQL.Add('			(R_0.Method = R.Method)');
    lQuery.SQL.Add('	ORDER BY R_0.Duration_Millis DESC');
    lQuery.SQL.Add('	LIMIT 1) L_J_HEA ON (1=1)');
    lQuery.SQL.Add('');
    lQuery.SQL.Add('LEFT JOIN LATERAL (');
    lQuery.SQL.Add('	SELECT ');
    lQuery.SQL.Add('		R_0.Queries,');
    lQuery.SQL.Add('		R_0.Duration_Millis, ');
    lQuery.SQL.Add('		R_0.Created_At');
    lQuery.SQL.Add('	FROM request R_0');
    lQuery.SQL.Add('	WHERE (R_0.Resource = R.Resource) AND ');
    lQuery.SQL.Add('			(R_0.Method = R.Method)');
    lQuery.SQL.Add('	ORDER BY R_0.Duration_Millis ASC');
    lQuery.SQL.Add('	LIMIT 1) L_J_LIG ON (1=1)');
    lQuery.Open();

    if lQuery.RecordCount = 0 then
      Exit;

    while not lQuery.Eof do
    begin
      SetLength(Stat, I + 1);
      Stat[I].MethodType := lQuery.FieldByName('Method').AsString;
      Stat[I].Resource := lQuery.FieldByName('Resource').AsString;
      Stat[I].RequestCount := lQuery.FieldByName('request_count').AsInteger;
      Stat[I].AvgDurationMillis := lQuery.FieldByName('avg_duration_millis').AsInteger;
      Stat[I].P95DurationMillis := lQuery.FieldByName('p95_duration_millis').AsInteger;
      Stat[I].P99DurationMillis := lQuery.FieldByName('p99_duration_millis').AsInteger;
      Stat[I].ErrorCount := lQuery.FieldByName('error_count').AsInteger;

      Stat[I].HeavierResourceQueries := lQuery.FieldByName('Heavier_Resource_Queries').AsString;
      Stat[I].HeavierResourceDurationMillis := lQuery.FieldByName('Heavier_Resource_Duration_Millis').AsInteger;
      Stat[I].HeavierResourceCreatedAt := lQuery.FieldByName('Heavier_Resource_Created_At').AsDateTime;

      Stat[I].LighterResourceQueries := lQuery.FieldByName('Lighter_Resource_Queries').AsString;
      Stat[I].LighterResourceDurationMillis := lQuery.FieldByName('Lighter_Resource_Duration_Millis').AsInteger;
      Stat[I].LighterResourceCreatedAt := lQuery.FieldByName('Lighter_Resource_Created_At').AsDateTime;

      Inc(I);
      lQuery.Next();
    end;
  finally
    lQuery.Free();
  end;
end;

procedure TPostgreSQLDataStore.GetTopExpensiveRequests(
  var Stat: TArray<TResource>);
var
  I: Integer;
  lQuery: TFDQuery;
begin
  I := 0;
  lQuery := TFDQuery.Create(nil);
  lQuery.Connection := FConnection;
  try
    lQuery.SQL.Add('SELECT *');
    lQuery.SQL.Add('FROM request');
    lQuery.SQL.Add('ORDER BY Duration_Millis DESC');
    lQuery.SQL.Add('LIMIT 5');
    lQuery.Open();

    while not lQuery.Eof do
    begin
      SetLength(Stat, I + 1);
      Stat[I].MethodType := lQuery.FieldByName('Method').AsString;
      Stat[I].Resource := lQuery.FieldByName('Resource').AsString;
      Stat[I].DurationMillis := lQuery.FieldByName('Duration_Millis').AsInteger;
      Stat[I].Queries := lQuery.FieldByName('Queries').AsString;
      Stat[I].ContextId := lQuery.FieldByName('Context_Id').AsString;
      Stat[I].CreateAt := lQuery.FieldByName('Created_At').AsDateTime;
      Stat[I].StatusCode := lQuery.FieldByName('Status_Code').AsInteger;
      Stat[I].ResponseBody := lQuery.FieldByName('Response_Body').AsString;
      Inc(I);
      lQuery.Next();
    end;
  finally
    lQuery.Free();
  end;
end;

procedure TPostgreSQLDataStore.GetRequestsPerMinute(
  var Stat: TArray<TRequestsPerMinuteStat>);
var
  I: Integer;
  lQuery: TFDQuery;
begin
  I := 0;
  lQuery := TFDQuery.Create(nil);
  lQuery.Connection := FConnection;
  try
    lQuery.SQL.Add('SELECT');
    lQuery.SQL.Add('  to_char(date_trunc(''minute'', Created_At), ''YYYY-MM-DD"T"HH24:MI:SS'') AS minute_bucket,');
    lQuery.SQL.Add('  COUNT(*) AS request_count');
    lQuery.SQL.Add('FROM request');
    lQuery.SQL.Add('WHERE Created_At >= NOW() - INTERVAL ''60 minutes''');
    lQuery.SQL.Add('GROUP BY date_trunc(''minute'', Created_At)');
    lQuery.SQL.Add('ORDER BY date_trunc(''minute'', Created_At) ASC');
    lQuery.Open();

    while not lQuery.Eof do
    begin
      SetLength(Stat, I + 1);
      Stat[I].MinuteBucket := lQuery.FieldByName('minute_bucket').AsString;
      Stat[I].RequestCount := lQuery.FieldByName('request_count').AsInteger;
      Inc(I);
      lQuery.Next();
    end;
  finally
    lQuery.Free();
  end;
end;

function TPostgreSQLDataStore.GetStatistics(
  out Statistics: TStatistics): Boolean;
begin
  GetGlobalStatistics(Statistics.GlobalStatistics);
  GetStatusCodeSummaryStat(Statistics.StatusCodeSummaryStatistics);
  GetMethodTypeSummaryStat(Statistics.MethodTypeSummaryStatistics);
  GetResourceSummaryStat(Statistics.ResourceSummaryStatistics);
  GetTopExpensiveRequests(Statistics.TopExpensiveRequests);
  GetRequestsPerMinute(Statistics.RequestsPerMinute);
  Result := True;
end;


procedure TPostgreSQLDataStore.PersistRequest(const Command: TNewRequestDataCommand);
var
  lQuery: TFDQuery;
begin
  lQuery := TFDQuery.Create(nil);
  lQuery.Connection := FConnection;
  try
    lQuery.SQL.Add('INSERT INTO request(');
    lQuery.SQL.Add('	resource, ');
    lQuery.SQL.Add('	queries, ');
    lQuery.SQL.Add('	method,');
    lQuery.SQL.Add('	duration_millis,');
    lQuery.SQL.Add('	context_id,');
    lQuery.SQL.Add('	created_at,');
    lQuery.SQL.Add('	status_code,');
    lQuery.SQL.Add('	response_body)');
    lQuery.SQL.Add('VALUES (');
    lQuery.SQL.Add('	:resource,');
    lQuery.SQL.Add('	:queries,');
    lQuery.SQL.Add('	:method,');
    lQuery.SQL.Add('	:duration_millis,');
    lQuery.SQL.Add('	:context_id,');
    lQuery.SQL.Add('	:created_at,');
    lQuery.SQL.Add('	:status_code,');
    lQuery.SQL.Add('	:response_body);');

    lQuery.ParamByName('resource').AsString := Command.Resource;
    lQuery.ParamByName('queries').AsString := Command.Queries;
    lQuery.ParamByName('method').AsString := Command.Method;
    lQuery.ParamByName('duration_millis').AsInteger := Command.DurationMillis;
    lQuery.ParamByName('context_id').AsString := Command.ContextId;
    lQuery.ParamByName('created_at').AsDateTime := Command.CreatedAt;
    lQuery.ParamByName('status_code').AsInteger := Command.StatusCode;
    lQuery.ParamByName('response_body').AsString := Command.ResponseBody;
    lQuery.ExecSQL();
  finally
    lQuery.Free();
  end;
end;

procedure TPostgreSQLDataStore.PersistSubRoutine(const Command: TNewSubRoutineDataCommand);
var
  lQuery: TFDQuery;
begin
  lQuery := TFDQuery.Create(nil);
  lQuery.Connection := FConnection;
  try
    lQuery.SQL.Add('INSERT INTO subroutine(');
    lQuery.SQL.Add('	name, ');
    lQuery.SQL.Add('	duration_millis,');
    lQuery.SQL.Add('	context_id)');
    lQuery.SQL.Add('VALUES (');
    lQuery.SQL.Add('	:name,');
    lQuery.SQL.Add('	:duration_millis,');
    lQuery.SQL.Add('	:context_id);');

    lQuery.ParamByName('duration_millis').AsInteger := Command.DurationMillis;
    lQuery.ParamByName('context_id').AsString := Command.ContextId;
    lQuery.ParamByName('name').AsString := Command.Routine;
    lQuery.ExecSQL();
  finally
    lQuery.Free();
  end;
end;

procedure TPostgreSQLDataStore.SetPGSearchPath(const Schema: String);
begin
  FConnection.ExecSQL('SET search_path TO ' + Schema + ', public;');
end;

procedure TPostgreSQLDataStore.CleanUp();
var
  lQuery: TFDQuery;
begin
  lQuery := TFDQuery.Create(nil);
  lQuery.Connection := FConnection;
  try
    lQuery.SQL.Clear();
    lQuery.SQL.Add('DELETE FROM web.request ');
    lQuery.SQL.Add('WHERE created_at <= CURRENT_DATE - INTERVAL ' + QuotedStr('1 week') + ';');
    lQuery.ExecSQL();

    lQuery.SQL.Clear();
    lQuery.SQL.Add('DELETE FROM web.request ');
    lQuery.SQL.Add('WHERE created_at <= CURRENT_DATE - INTERVAL ' + QuotedStr('1 week') + ';');
    lQuery.ExecSQL();
  finally
    lQuery.Free();
  end;
end;

destructor TPostgreSQLDataStore.Destroy();
begin
  FConnection.Free();
  FDriverLink.Free();
  inherited;
end;

{ TPostgreSQLDataStoreBuilder }

function TPostgreSQLDataStoreBuilder.Build(): IDataStore;
begin
  Result := TPostgreSQLDataStore.Create(
    FSchema,
    FServer,
    FDatabase,
    FPassword,
    FUsername,
    FVendorLib);
end;

function TPostgreSQLDataStoreBuilder.Database(
  const Value: String): TPostgreSQLDataStoreBuilder;
begin
  FDatabase := Value;

  Result := Self;
end;

class function TPostgreSQLDataStoreBuilder.New(): TPostgreSQLDataStoreBuilder;
begin
  Result.Schema('public');
end;

function TPostgreSQLDataStoreBuilder.Password(
  const Value: String): TPostgreSQLDataStoreBuilder;
begin
  FPassword := Value;
  Result := Self;
end;

function TPostgreSQLDataStoreBuilder.Schema(
  const Value: String): TPostgreSQLDataStoreBuilder;
begin
  FSchema := Value;
  Result := Self;
end;

function TPostgreSQLDataStoreBuilder.Server(
  const Value: String): TPostgreSQLDataStoreBuilder;
begin
  FServer := Value;
  Result := Self;
end;

function TPostgreSQLDataStoreBuilder.Username(
  const Value: String): TPostgreSQLDataStoreBuilder;
begin
  FUsername := Value;
  Result := Self;
end;

function TPostgreSQLDataStoreBuilder.VendorLib(
  const Value: String): TPostgreSQLDataStoreBuilder;
begin
  FVendorLib := Value;
  Result := Self;
end;

end.

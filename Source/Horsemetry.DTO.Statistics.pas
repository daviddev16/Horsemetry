unit Horsemetry.DTO.Statistics;

interface

type
  TGlobalStatistics = record
    UniqueContextsCount: Integer;
    TotalErrors: Integer;
    TotalSuccess: Integer;
  end;

  TStatusCodeSummaryStat = record
    StatusCode: Integer;
    RequestCount: Integer;
  end;

  TMethodTypeSummaryStat = record
    MethodType: String;
    RequestCount: Integer;
    MinDurationMillis: Integer;
    MaxDurationMillis: Integer;
    AvgDurationMillis: Integer;
    P95DurationMillis: Integer;
    P99DurationMillis: Integer;
    ErrorCount: Integer;
  end;

  TResourceSummaryStat = record
    MethodType: String;
    Resource: String;
    RequestCount: Integer;
    AvgDurationMillis: Integer;
    P95DurationMillis: Integer;
    P99DurationMillis: Integer;
    ErrorCount: Integer;

    HeavierResourceQueries: String;
    HeavierResourceDurationMillis: Integer;
    HeavierResourceCreatedAt: TDateTime;

    LighterResourceQueries: String;
    LighterResourceDurationMillis: Integer;
    LighterResourceCreatedAt: TDateTime;
  end;

  TResource = record
    MethodType: String;
    Resource: String;
    DurationMillis: Integer;
    ContextId: String;
    CreateAt: TDateTime;
    Queries: String;
    StatusCode: Integer;
    ResponseBody: String;
  end;

  TResourceList = TArray<TResource>;

  TRequestsPerMinuteStat = record
    MinuteBucket: String;
    RequestCount: Integer;
  end;

  TStatistics = record
    GlobalStatistics: TGlobalStatistics;
    StatusCodeSummaryStatistics: TArray<TStatusCodeSummaryStat>;
    MethodTypeSummaryStatistics: TArray<TMethodTypeSummaryStat>;
    ResourceSummaryStatistics: TArray<TResourceSummaryStat>;
    TopExpensiveRequests: TArray<TResource>;
    RequestsPerMinute: TArray<TRequestsPerMinuteStat>;
  end;

implementation

end.

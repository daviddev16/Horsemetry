unit MyDataStoreProvider;

interface

uses
  Horsemetry.DataStore,
  Horsemetry.PGDataStore;

type
  TShopAPIDataStoreProvider = class(TInterfacedObject, IDataStoreProvider)
    public
      function NewDataStore(): IDataStore;
    end;


implementation

{ TShopAPIDataStoreProvider }

function TShopAPIDataStoreProvider.NewDataStore(): IDataStore;
begin
  Result := TPostgreSQLDataStoreBuilder.New()
      .Schema('web')
      .Server('127.0.0.1')
      .Database('postgres')
      .Username('postgres')
      .Password('#abc123#')
      .VendorLib('C:\Program Files (x86)\PostgreSQL\9.5\bin\libpq.dll')
      .Build();
end;

end.

# 🐴 Horsemetry

**A sua API de olhos abertos.**

Horsemetry é uma poderosa biblioteca de observabilidade e telemetria para o framework [Horse](https://github.com/HashLoad/horse). Ela injeta superpoderes analíticos na sua aplicação Delphi, oferecendo um painel visual deslumbrante e insights em tempo real sobre a saúde e a performance dos seus endpoints.

Deixe de "achar" que sua API está rápida e passe a ter certeza absoluta!

---

## 🎯 Recursos Oferecidos

No dashboard frontend do Horsemetry, você tem acesso aos seguintes dados e visualizações:

- **Métricas Globais:** Total de requisições, tempo médio global, requisições mais lentas e taxa de sucesso.
- **Gráficos em Tempo Real:**
  - Requisições por Minuto.
  - Latência ao Longo do Tempo.
  - Proporção de Tempo Gasto pelas 5 requisições mais lentas.
  - Distribuição de requisições por Método HTTP.
  - Distribuição de requisições por Status Code.
  - Tempo Médio por Recurso (rota).
- **Tabelas Analíticas:**
  - Resumo de performance agrupado por Método.
  - Resumo de performance agrupado por Recurso/Rota (exibindo tempo médio, p95, p99 e quantidade de erros).
  - Top 5 requisições mais lentas do histórico.
  - Log detalhado de requisições recentes com suporte a filtros (por método, status e data).
- **Inspeção Detalhada:** Expansão de linhas de log para visualização do corpo (body) das respostas de erro e o tempo gasto em sub-rotinas internas.

---



## 🚀 Primeiros Passos

O Horsemetry utiliza uma arquitetura baseada em Providers para instanciar as conexões com o banco de telemetria em threads separadas quando necessário.

### 1. Criando o seu Provider

Implemente a interface `IDataStoreProvider` que será responsável por fornecer a instância do banco:

```delphi
unit MyDataStoreProvider;

interface

uses
  Horsemetry.DataStore,
  Horsemetry.PGDataStore;

type
  TMyDataStoreProvider = class(TInterfacedObject, IDataStoreProvider)
    public
      function NewDataStore(): IDataStore;
    end;

implementation

function TMyDataStoreProvider.NewDataStore(): IDataStore;
begin
  Result := TPostgreSQLDataStoreBuilder.New()
      .Schema('public') // opcional
      .Server('127.0.0.1')
      .Database('telemetry_db')
      .Username('postgres')
      .Password('masterkey')
      .VendorLib('C:\Program Files\PostgreSQL\14\bin\libpq.dll') // Opcional se no PATH
      .Build();
end;

end.
```

### 2. Acoplando ao Horse (Seu DPR)

Configure o provider, instale as rotas de telemetria, adicione o middleware base do Horsemetry e inicie a captura em background:

```delphi
program SeuProjetoAPI;

{$APPTYPE CONSOLE}

uses
  Horse,
  Horsemetry,
  MyDataStoreProvider;

begin
  // 1. Informando a sua classe provedora de banco para o Horsemetry
  THorsemetry.SetDataStoreProviderClass(TMyDataStoreProvider);
  
  // 2. Injetando a rota de painel (ex. /telemetry) automaticamente
  THorsemetry.InstallRoutes();
  
  // 3. Adicionando o Middleware Global no Horse
  THorse.Use(Telemetry);

  // 4. Suas rotas normais...
  THorse.All('/ping',
    procedure(Req: THorseRequest; Res: THorseResponse)
    begin
      // Opcional: injetando e rastreando sub-rotinas dentro do request!
      THorsemetry.PushSubRoutine('ConectandoDB', 15);
      
      Res.Status(200).Send('pong');
    end);

  // 5. Iniciando o servidor E a captura assíncrona
  THorse.Listen(9000, 
    procedure
    begin
      Writeln('Server listening on port 9000');
      
      // Inicia a thread que irá processar a fila de telemetria em background
      THorsemetry.StartCapture();
    end);
end.
```

---

## 📊 Acessando o Dashboard

O Horsemetry já expõe por conta própria uma interface web injetada e segura dentro da sua API.

Logo após rodar a sua aplicação, abra o seu navegador e acesse a rota `/telemetry`:

👉 **[http://localhost:9000/telemetry](http://localhost:9000/telemetry)**

Lá você encontrará a interface completa com relógios em tempo real, visualização de logs, listagem do Top 5 rotas mais lentas, além dos gráficos e detalhes de cada sub-rotina.

---

## 🛠️ Build do Arquivo HTML

A interface maravilhosa do dashboard vive no arquivo `index.html`. 
Se você desejar aplicar alguma mudança (novas cores, traduções ou novas lógicas), basta editar o `index.html` raiz do projeto Horsemetry.

O HTML é empacotado dentro de um arquivo de recursos (`.res`) para ser distribuído junto ao executável da sua API, sem necessidade de arquivos externos.

Para aplicar e compilar suas alterações:

1. Modifique e salve o arquivo `index.html`.
2. Execute o script **`Build_HTML_Resource.bat`** (disponível na raiz do projeto). Ele compilará o recurso atualizado automaticamente.
3. Realize o build do seu projeto Delphi. As alterações estarão disponíveis imediatamente no endereço `/telemetry`.

---

🐎 **Cavalgue rumo ao controle absoluto do seu Backend com o Horsemetry!**

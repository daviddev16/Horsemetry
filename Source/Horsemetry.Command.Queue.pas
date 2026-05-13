unit Horsemetry.Command.Queue;

interface

uses
  System.Types,
  System.SysUtils,
  System.Generics.Collections;

type
  TCommandQueue = class sealed
    strict private
      class var Queue: TThreadedQueue<String>;
    public
      class procedure Push(const JSONCommand: String);
      class function Pop(var JSONCommand: String): Boolean;
    protected
      class destructor Unitialize();
      class constructor Initialize();
    end;

implementation

{ TCommandQueue }

class constructor TCommandQueue.Initialize();
begin
  if Assigned(Queue) then
    Exit;
  Queue := TThreadedQueue<String>.Create(2048);
end;

class function TCommandQueue.Pop(var JSONCommand: String): Boolean;
begin
  Result := Queue.PopItem(JSONCommand) = wrSignaled;
end;

class procedure TCommandQueue.Push(const JSONCommand: String);
begin
  Queue.PushItem(JSONCommand);
end;

class destructor TCommandQueue.Unitialize();
begin
  if not Assigned(Queue) then
    Exit;
  Queue.DoShutDown();
  FreeAndNil(Queue);
end;

end.

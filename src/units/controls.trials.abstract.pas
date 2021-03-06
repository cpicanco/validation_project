{
  Stimulus Control
  Copyright (C) 2014-2017 Carlos Rafael Fernandes Picanço, Universidade Federal do Pará.

  The present file is distributed under the terms of the GNU General Public License (GPL v3.0).

  You should have received a copy of the GNU General Public License
  along with this program. If not, see <http://www.gnu.org/licenses/>.
}
unit Controls.Trials.Abstract;

{$mode objfpc}{$H+}

interface

uses LCLIntf, LCLType, Controls, ExtCtrls, Classes, SysUtils, LCLProc

  , Session.Configuration
  , countermanager
  , Schedules
  , Devices.RS232i
  //, interface_plp
  ;

type

  { TObjectProcedure }

  TPaintEvent = procedure of object;

  { TTrial }

  TTrial = class(TGraphicControl)
  private
    FGlobalContainer: TGlobalContainer;
    FCfgTrial: TCfgTrial;
    FClock : TTimer;
    FCounterManager : TCounterManager;
    FLogEvent: TDataProcedure;
    FClockList : array of TThreadMethod;
    FData,
    FFilename,
    FHeader,
    FHeaderTimestamps,
    FResult,
    FIETConsequence,
    FNextTrial : string;
    FStarterLatency : Extended;
    FLimitedHold,
    FTimeOut : Integer;
    FShowStarter : Boolean;
    function GetRootMedia: string;
    function GetTestMode: Boolean;
    function GetTimeStart: Extended;
    procedure BeginStarter;
    procedure SetRootMedia(AValue: string);
    procedure SetTestMode(AValue: Boolean);
    procedure StartClockList;
    procedure StartTrial(Sender: TObject);
    procedure TrialKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure TrialKeyUp(Sender: TObject; var Key: Word; Shift: TShiftState);
  private
    FOnBeginCorrection: TNotifyEvent;
    FOnBkGndResponse: TNotifyEvent;
    FOnConsequence: TNotifyEvent;
    FOnEndCorrection: TNotifyEvent;
    FOnHit: TNotifyEvent;
    FOnMiss: TNotifyEvent;
    FOnNone: TNotifyEvent;
    FOnStmResponse: TNotifyEvent;
    FOnTrialBeforeEnd: TNotifyEvent;
    FOnTrialEnd: TNotifyEvent;
    FOnTrialKeyDown: TKeyEvent;
    FOnTrialKeyUp: TKeyEvent;
    FOnTrialPaint: TPaintEvent;
    FOnTrialStart: TNotifyEvent;
    FOnTrialWriteData: TNotifyEvent;
    FOldKeyUp : TKeyEvent;
    FOldKeyDown: TKeyEvent;
    procedure EndTrialThread(Sender: TObject);
    procedure SetOnTrialBeforeEnd(AValue: TNotifyEvent);
    procedure SetOnBeginCorrection(AValue: TNotifyEvent);
    procedure SetOnBkGndResponse(AValue: TNotifyEvent);
    procedure SetOnConsequence(AValue: TNotifyEvent);
    procedure SetOnEndCorrection(AValue: TNotifyEvent);
    procedure SetOnTrialEnd(AValue: TNotifyEvent);
    procedure SetOnHit(AValue: TNotifyEvent);
    procedure SetOnMiss(AValue: TNotifyEvent);
    procedure SetOnNone(AValue: TNotifyEvent);
    procedure SetOnStmResponse(AValue: TNotifyEvent);
    procedure SetOnTrialKeyDown(AValue: TKeyEvent);
    procedure SetOnTrialKeyUp(AValue: TKeyEvent);
    procedure SetOnTrialPaint(AValue: TPaintEvent);
    procedure SetOnTrialStart(AValue: TNotifyEvent);
    procedure SetOnTrialWriteData(AValue: TNotifyEvent);
  strict protected
    FResponseEnabled,
    FIscorrection : Boolean;
    {$ifdef DEBUG}
      procedure ClockStatus(msg : string);
    {$endif}
    procedure AddToClockList(AClockStart : TThreadMethod); overload;
    procedure AddToClockList(ASchedule: TSchedule); overload;
    procedure EndTrial(Sender: TObject);
    procedure LogEvent(ACode: string);
    procedure Config(Sender: TObject);
    procedure WriteData(Sender: TObject); virtual;
    property OnTrialKeyDown : TKeyEvent read FOnTrialKeyDown write SetOnTrialKeyDown;
    property OnTrialKeyUp : TKeyEvent read FOnTrialKeyUp write SetOnTrialKeyUp;
    property OnTrialPaint: TPaintEvent read FOnTrialPaint write SetOnTrialPaint;
    property OnTrialStart: TNotifyEvent read FOnTrialStart write SetOnTrialStart;
  protected
    procedure Paint; override;
    procedure Dispenser(AParallelPort: Byte; ARS232: string);
  public
    constructor Create (ACustomControlOwner : TComponent); override;
    destructor Destroy; override;
    procedure Play(ACorrection: Boolean=False); virtual;
    procedure Hide;virtual;
    procedure SetFocus;virtual;
    property CfgTrial: TCfgTrial read FCfgTrial write FCfgTrial;
    property CounterManager : TCounterManager read FCounterManager write FCounterManager;
    property Data: string read FData write FData;
    property FileName : string read FFilename write FFilename;
    property GlobalContainer : TGlobalContainer read FGlobalContainer write FGlobalContainer;
    property Header: string read FHeader write FHeader;
    property HeaderTimestamps: string read FHeaderTimestamps write FHeaderTimestamps;
    property IETConsequence : string read FIETConsequence write FIETConsequence;
    property NextTrial: string read FNextTrial write FNextTrial;
    property Result: string read FResult write FResult;
    property RootMedia : string read GetRootMedia write SetRootMedia;
    property SaveTData : TDataProcedure read FLogEvent write FLogEvent;
    property TestMode : Boolean read GetTestMode write SetTestMode;
    property TimeOut : Integer read FTimeOut write FTimeOut;
    property TimeStart : Extended read GetTimeStart;
  public
    property OnTrialBeforeEnd: TNotifyEvent read FOnTrialBeforeEnd write SetOnTrialBeforeEnd;
    property OnBeginCorrection : TNotifyEvent read FOnBeginCorrection write SetOnBeginCorrection;
    property OnBkGndResponse: TNotifyEvent read FOnBkGndResponse write SetOnBkGndResponse;
    property OnConsequence: TNotifyEvent read FOnConsequence write SetOnConsequence;
    property OnEndCorrection : TNotifyEvent read FOnEndCorrection write SetOnEndCorrection;
    property OnTrialEnd: TNotifyEvent read FOnTrialEnd write SetOnTrialEnd;
    property OnHit: TNotifyEvent read FOnHit write SetOnHit;
    property OnMiss: TNotifyEvent read FOnMiss write SetOnMiss;
    property OnNone: TNotifyEvent read FOnNone write SetOnNone;
    property OnStmResponse: TNotifyEvent read FOnStmResponse write SetOnStmResponse;
    property OnTrialWriteData: TNotifyEvent read FOnTrialWriteData write SetOnTrialWriteData;
  end;

resourcestring
  SESSION_CANCELED = '(Sessão cancelada)';

implementation


uses constants, timestamps, Canvas.Helpers
    {$ifdef DEBUG}
    , Loggers.Debug
    {$endif}
    ;

{ TTrial }

{$ifdef DEBUG}
procedure TTrial.ClockStatus(msg: string);
begin
  DebugLn(msg);
end;
{$endif}

procedure TTrial.Config(Sender: TObject);
begin
  FStarterLatency := TimeStart;
  if FShowStarter then
    begin
      LogEvent('S');
      BeginStarter;
      Exit;
    end;

  StartTrial(Sender);
end;

procedure TTrial.WriteData(Sender: TObject);
begin
  Data := Result + #9;
  if FStarterLatency <> TimeStart then
    Data := Data + TimestampToStr(FStarterLatency - TimeStart) + #9;
end;

procedure TTrial.TrialKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
begin
  if FResponseEnabled and (Key = 27 {ESC}) then
    begin
      FResponseEnabled:= False;
      Invalidate;
      Exit;
    end;

  if (ssCtrl in shift) and (Key = 113 { q }) then
    begin
      FResponseEnabled:= False;
      Data := Data + LineEnding + SESSION_CANCELED + LineEnding;
      Result := T_NONE;
      IETConsequence := T_NONE;
      NextTrial := T_END;
      FClock.Enabled := False;
      Exit;
    end;

  if (ssCtrl in Shift) and (Key = 13 { Enter }) then
    begin
      FResponseEnabled := False;
      Result := T_NONE;
      IETConsequence := T_NONE;
      NextTrial := '0';
      FClock.Enabled := False;  // EndTrial(Self);
      Exit;
    end;

  if Assigned(OnTrialKeyDown) and FResponseEnabled then OnTrialKeyDown(Sender,Key,Shift);
end;

procedure TTrial.TrialKeyUp(Sender: TObject; var Key: Word; Shift: TShiftState);
begin
  if (not FResponseEnabled) and (Key = 27) { ESC } then
    begin
      FResponseEnabled:= True;
      Invalidate;
      Exit;
    end;

  if FShowStarter and (Key = 32) { SPACE } then
    begin
      FShowStarter := False;
      FStarterLatency := TickCount;
      StartTrial(Sender);
      Exit;
    end;

  if Assigned(OnTrialKeyUp) and FResponseEnabled then OnTrialKeyUp(Sender,Key,Shift);
end;

procedure TTrial.EndTrial(Sender: TObject);
begin
  {$ifdef DEBUG}
    DebugLn(mt_Debug + 'TTrial.EndTrial1');
  {$endif}
  if FLimitedHold = 0 then
    if Assigned(FClock) then
      //FClock.Enabled := False;
      EndTrialThread(Sender);
end;

procedure TTrial.EndTrialThread(Sender: TObject);
begin
  FClock.OnStopTimer := nil;
  FClock.Enabled := False;
  {$ifdef DEBUG}
    DebugLn(mt_Debug + 'TTrial.EndTrial2');
  {$endif}

  LogEvent('TE');
  FResponseEnabled:= False;
  Hide;
  if Assigned(OnTrialBeforeEnd) then OnTrialBeforeEnd(Sender);
  if Parent is TCustomControl then
    with TCustomControl(Parent) do
      begin
        OnKeyDown := FOldKeyDown;
        OnKeyUp := FOldKeyUp;
      end;
  case Result of
    T_HIT : if Assigned(OnHit) then OnHit(Sender);
    T_MISS: if Assigned(OnMiss) then OnMiss(Sender);
    T_NONE: if Assigned(OnNone) then OnNone(Sender);
  end;

  if FIsCorrection then
    if Assigned(OnEndCorrection) then OnEndCorrection(Sender);

  if Assigned(OnTrialEnd) then OnTrialEnd(Sender);
end;

procedure TTrial.Paint;
begin
  inherited Paint;
  if FShowStarter then
    begin
      DrawCenteredCircle(Canvas, Width, Height, 6);
      Exit;
    end;
  if Assigned(OnTrialPaint) and FResponseEnabled then OnTrialPaint;
end;

procedure TTrial.Dispenser(AParallelPort: Byte; ARS232: string);
begin
    //PLP.OutPortOn(Csq);
    if ARS232 <> '' then
      RS232.Dispenser(ARS232);
end;

constructor TTrial.Create(ACustomControlOwner: TComponent);
begin
  Assert(ACustomControlOwner is TCustomControl, 'Owner of TTrial must be a TCustomControl.');
  inherited Create(ACustomControlOwner);
  FResponseEnabled := False;
  FShowStarter := False;
  NextTrial := '0';
  Result := T_NONE;
  IETConsequence := T_NONE;
  Color := 0;
  Cursor:= -1;
  Align := alClient;
  with TCustomControl(ACustomControlOwner) do
    begin
      FOldKeyUp := OnKeyUp;
      FOldKeyDown := OnKeyDown;
      OnKeyUp := @TrialKeyUp;
      OnKeyDown := @TrialKeyDown;
    end;
  Parent := TWinControl(ACustomControlOwner);

  //FLimitedhold is controlled by a TTrial descendent. It controls Trial ending.
  FLimitedHold := 0;
  FClock := TTimer.Create(Self);
  FClock.Interval := FLimitedHold;
  FClock.Enabled := False;
  FClock.OnTimer := @EndTrialThread;
  FClock.OnStopTimer := @EndTrialThread;

  // setup report header
  // descendents should concatenate its own data, if any, to in their OnCreate method
  Header := rsReportCsqRes;

  // setup timestamps header
  // descendents should concatenate its own data, if any, to in their OnCreate method
  HeaderTimestamps := rsReportTime + #9 +
                      rsReportBlocID + #9 +
                      rsReportTrialID + #9 +
                      rsReportTrialNO + #9 +
                      rsReportEvent;
end;

destructor TTrial.Destroy;
begin
  {$ifdef DEBUG}
    DebugLn(mt_Debug + 'TTrial.Destroy:FNextTrial:' + FNextTrial);
  {$endif}

  //if Assigned(FClock) then
  //  begin
  //    FClock.OnTimer := nil;
  //    FClock.Enabled := False;
  //    FClock.Terminate;
  //    FClock := nil;
  //  end;
  inherited Destroy;
end;

procedure TTrial.Play(ACorrection: Boolean);
begin
  // avoid responses while loading configurations
  FResponseEnabled := False;

  // full path for loading media files
  RootMedia:= FGlobalContainer.RootMedia;

  // what will be the next trial?
  NextTrial := CfgTrial.SList.Values[_NextTrial];

  // will the trial count as MISS, HIT or NONE?
  Result := CfgTrial.SList.Values[_cRes];
  if Result = '' then
    Result := T_NONE;

  // what will happen during the inter trial interval?
  IETConsequence := T_NONE;

  // is it a correction trial?
  if ACorrection then
    FIsCorrection := True
  else
    FIsCorrection := False;

  // Trial background color
  Color:= StrToIntDef(CfgTrial.SList.Values[_BkGnd], Parent.Color);

  // Trial will last LimitedHold ms if LimitedHold > 0
  FLimitedHold := StrToIntDef(CfgTrial.SList.Values[_LimitedHold], 0);
  FClock.Interval := FLimitedHold;

  // Present a dot at the screen center. A key response is required before trialstart
  FShowStarter := StrToBoolDef(CfgTrial.SList.Values[_ShowStarter], False);
  if FShowStarter then
    Header := 'Str.Lat.' + #9 + Header;

  // image of the mouse cursor
  if TestMode then Cursor:= 0
  else Cursor:= StrToIntDef(CfgTrial.SList.Values[_Cursor], 0);
end;

procedure TTrial.Hide;
var
  i : integer;
begin
  inherited Hide;
  if ComponentCount > 0 then
    for i := 0 to ComponentCount -1 do
      if Components[i] is TControl then
        TControl(Components[i]).Hide;
end;

procedure TTrial.SetFocus;
begin
  TCustomControl(Parent).SetFocus;
end;

procedure TTrial.AddToClockList(AClockStart: TThreadMethod);
begin
  SetLength(FClockList, Length(FClockList) + 1);
  FClockList[Length(FClockList) - 1] := AClockStart;
end;

procedure TTrial.BeginStarter;
begin
  FResponseEnabled:= True;
  Show;
end;

procedure TTrial.StartClockList;
var
  i : integer;
begin
  if FClock.Interval > 0 then
    FClock.Enabled := True;
  for i := 0 to Length(FClockList) -1 do
    TThreadMethod(FClockList[i]);
  SetLength(FClockList, 0);
end;

procedure TTrial.StartTrial(Sender: TObject);
begin
  LogEvent('TS');
  StartClockList;
  FResponseEnabled := True;
  Show;
  SetFocus;
  if FIsCorrection then
    if Assigned (OnBeginCorrection) then OnBeginCorrection(Sender);
  if Assigned(OnTrialStart) then OnTrialStart(Sender);
end;

procedure TTrial.LogEvent(ACode: string);
begin
  SaveTData(TimestampToStr(TickCount - TimeStart) + #9 +
           IntToStr(CounterManager.CurrentBlc+1) + #9 +
           IntToStr(CounterManager.CurrentTrial+1) + #9 +
           IntToStr(CounterManager.Trials+1) + #9 + // Current trial cycle
           ACode + LineEnding)
end;

procedure TTrial.AddToClockList(ASchedule: TSchedule);
begin
  if ASchedule.Loaded then
    AddToClockList(@ASchedule.Start)
  else
    raise Exception.Create(ExceptionNoScheduleFound);
end;

procedure TTrial.SetOnTrialBeforeEnd(AValue: TNotifyEvent);
begin
  if FOnTrialBeforeEnd = AValue then Exit;
  FOnTrialBeforeEnd := AValue;
end;

procedure TTrial.SetOnBeginCorrection(AValue: TNotifyEvent);
begin
  if FOnBeginCorrection = AValue then Exit;
  FOnBeginCorrection := AValue;
end;

procedure TTrial.SetOnBkGndResponse(AValue: TNotifyEvent);
begin
  if FOnBkGndResponse = AValue then Exit;
  FOnBkGndResponse := AValue;
end;

procedure TTrial.SetOnConsequence(AValue: TNotifyEvent);
begin
  if FOnConsequence = AValue then Exit;
  FOnConsequence := AValue;
end;

procedure TTrial.SetOnEndCorrection(AValue: TNotifyEvent);
begin
  if FOnEndCorrection = AValue then Exit;
  FOnEndCorrection := AValue;
end;

procedure TTrial.SetOnTrialEnd(AValue: TNotifyEvent);
begin
  if FOnTrialEnd = AValue then Exit;
  FOnTrialEnd := AValue;
end;

procedure TTrial.SetOnHit(AValue: TNotifyEvent);
begin
  if FOnHit = AValue then Exit;
  FOnHit := AValue;
end;

procedure TTrial.SetOnMiss(AValue: TNotifyEvent);
begin
  if FOnMiss = AValue then Exit;
  FOnMiss := AValue;
end;

procedure TTrial.SetOnNone(AValue: TNotifyEvent);
begin
  if FOnNone = AValue then Exit;
  FOnNone := AValue;
end;

procedure TTrial.SetOnTrialStart(AValue: TNotifyEvent);
begin
  if FOnTrialStart = AValue then Exit;
  FOnTrialStart := AValue;
end;

procedure TTrial.SetOnStmResponse(AValue: TNotifyEvent);
begin
  if FOnStmResponse = AValue then Exit;
  FOnStmResponse := AValue;
end;

procedure TTrial.SetOnTrialKeyDown(AValue: TKeyEvent);
begin
  if FOnTrialKeyDown = AValue then Exit;
  FOnTrialKeyDown := AValue;
end;

procedure TTrial.SetOnTrialKeyUp(AValue: TKeyEvent);
begin
  if FOnTrialKeyUp = AValue then Exit;
  FOnTrialKeyUp := AValue;
end;

procedure TTrial.SetOnTrialPaint(AValue: TPaintEvent);
begin
  if FOnTrialPaint = AValue then Exit;
  FOnTrialPaint := AValue;
end;

procedure TTrial.SetOnTrialWriteData(AValue: TNotifyEvent);
begin
  if FOnTrialWriteData = AValue then Exit;
  FOnTrialWriteData := AValue;
end;

function TTrial.GetRootMedia: string;
begin
  Result := FGlobalContainer.RootMedia;
end;

function TTrial.GetTestMode: Boolean;
begin
  Result := FGlobalContainer.TestMode;
end;

function TTrial.GetTimeStart: Extended;
begin
  Result := FGlobalContainer.TimeStart;
end;

procedure TTrial.SetRootMedia(AValue: string);
begin
  if FGlobalContainer.RootMedia=AValue then Exit;
  FGlobalContainer.RootMedia:=AValue;
end;

procedure TTrial.SetTestMode(AValue: Boolean);
begin
  if FGlobalContainer.TestMode=AValue then Exit;
  FGlobalContainer.TestMode:=AValue;
end;


end.

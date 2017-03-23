{
  Stimulus Control
  Copyright (C) 2014-2017 Carlos Rafael Fernandes Picanço, Universidade Federal do Pará.

  The present file is distributed under the terms of the GNU General Public License (GPL v3.0).

  You should have received a copy of the GNU General Public License
  along with this program. If not, see <http://www.gnu.org/licenses/>.
}
unit blocs;

{$mode objfpc}{$H+}

interface

uses Classes, Controls, LCLIntf, LCLType,
     ExtCtrls, SysUtils, Graphics, Forms,
     Dialogs,StdCtrls

     , config_session
     , response_key
     , countermanager
     , custom_timer
     , trial_abstract
        , trial_message
        , trial_simple
        , trial_mirrored_stm
        , trial_feature_positive
        , trial_calibration
        , trial_matching
        , trial_dizzy_timers
        , trial_move_square
        , trial_go_nogo
     ;

type

  TFakeTimer = record
    Interval : LongInt;
    Enabled : Boolean;
  end;

  { TBlc }

  TBlc = class(TComponent)
  private
    function GetTimeStart: Extended;
    procedure LogEvent(ACode : string);
  private
    FNextBlc: String;
    FSaveData: TDataProcedure;
    FSaveTData: TDataProcedure;

    // session/global parameters
    FServerAddress: string;
    FShowCounter : Boolean;
    FTestMode: Boolean;
    FIsCorrection : Boolean;

    FBlcHeader: string;

    FLastTrialHeader,
    FLastData,
    FLastITIData : string;
    FFirstTrialBegin,
    FITIBegin,
    FITIEnd : Extended;

    // Clock System
    FTimer : TClockThread;
    FTimerCsq : TFakeTimer;
    FTimerITI: TFakeTimer;
    FTimerTO : TFakeTimer;

    // main objects/components
    FGlobalContainer: TGlobalContainer;
    FBackGround: TWinControl;
    FBlc: TCfgBlc;
    FTrial: TTrial;
    FCounterManager : TCounterManager;
    FCounterLabel : TLabel;
    FIETMedia : TKey;

    // events
    FOnBeginCorrection : TNotifyEvent;
    FOnBkGndResponse: TNotifyEvent;
    FOnConsequence: TNotifyEvent;
    FOnCriteria: TNotifyEvent;
    FOnEndBlc: TNotifyEvent;
    FOnEndCorrection : TNotifyEvent;
    FOnTrialEnd: TNotifyEvent;
    FOnHit: TNotifyEvent;
    FOnMiss: TNotifyEvent;
    FOnStmResponse: TNotifyEvent;
    procedure CreateIETMedia(FileName, HowManyLoops, Color : String);
    {$ifdef DEBUG}
       procedure DebugStatus(msg : string);
    {$endif}
    procedure PlayTrial;
    //procedure ShowCounterPlease (Kind : String);
    // events
    procedure BkGndResponse(Sender: TObject);
    procedure ClockThread(Sender: TObject);
    procedure EndBlc(Sender: TObject);
    procedure EndTrial(Sender: TObject);
    procedure IETConsequence(Sender: TObject);
    procedure IETKeyUp(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure IETResponse(Sender: TObject);
    procedure StmResponse(Sender: TObject);
    procedure TrialTerminate(Sender: TObject);
    procedure WriteTrialData(Sender: TObject);
    procedure Hit(Sender: TObject);
    procedure Miss(Sender: TObject);
    procedure None(Sender: TObject);
    property TimeStart : Extended read GetTimeStart;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    procedure Play(ACfgBlc: TCfgBlc; AManager : TCountermanager; AGlobalContainer: TGlobalContainer);
    property BackGround: TWinControl read FBackGround write FBackGround;
    property NextBlc: String read FNextBlc write FNextBlc;
    property SaveData : TDataProcedure read FSaveData write FSaveData;
    property SaveTData : TDataProcedure read FSaveTData write FSaveTData;
    property ServerAddress : string read FServerAddress write FServerAddress;
    property ShowCounter : Boolean read FShowCounter write FShowCounter;
  public
    property OnBeginCorrection: TNotifyEvent read FOnBeginCorrection write FOnBeginCorrection;
    property OnBkGndResponse : TNotifyEvent read FOnBkGndResponse write FOnBkGndResponse;
    property OnConsequence : TNotifyEvent read FOnConsequence write FOnConsequence;
    property OnCriteria: TNotifyEvent read FOnCriteria write FOnCriteria;
    property OnEndBlc: TNotifyEvent read FOnEndBlc write FOnEndBlc;
    property OnEndCorrection: TNotifyEvent read FOnEndCorrection write FOnEndCorrection;
    property OnTrialEnd : TNotifyEvent read FOnTrialEnd write FOnTrialEnd;
    property OnHit: TNotifyEvent read FOnHit write FOnHit;
    property OnMiss: TNotifyEvent read FOnMiss write FOnMiss;
    property OnStmResponse : TNotifyEvent read FOnStmResponse write FOnStmResponse;
  end;

implementation

uses strutils, constants, timestamps
     {$ifdef DEBUG}
     , debug_logger
     {$endif}
     ;
constructor TBlc.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  with FTimerITI do begin
    Interval := 0;
    Enabled := False;
  end;

  with FTimerTO do begin
    Interval := 0;
    Enabled := False;
  end;

  with FTimerCsq do begin
    Interval := 0;
    Enabled := False;
  end;

  FTimer := TClockThread.Create(True);
  FTimer.OnTimer := @ClockThread;
  {$ifdef DEBUG}
    FTimer.OnDebugStatus := @DebugStatus;
  {$endif}
  FTimer.Enabled := False;
  FTimer.Start;
end;

destructor TBlc.Destroy;
begin
  FTimer.Enabled := False;
  FTimer.Terminate;
  inherited Destroy;
end;

procedure TBlc.Play(ACfgBlc: TCfgBlc; AManager: TCountermanager; AGlobalContainer: TGlobalContainer);
begin
  FBlc:= ACfgBlc;
  FCounterManager := AManager;
  FGlobalContainer:= AGlobalContainer;
  FBackGround.OnKeyUp:=@IETKeyUp;
  FLastTrialHeader:= '';
  FIsCorrection := False;

  FBlcHeader:= 'Bloc__Id' + #9 + 'Bloc_Nam' + #9 + 'Trial_No'+ #9 + 'Trial_Id'+ #9 + 'TrialNam' + #9;
  //SaveData(FBlc.Name + LineEnding);

  PlayTrial;
end;

procedure TBlc.PlayTrial;
var IndTrial : integer;
begin
  if Assigned(FIETMedia) then
    FIETMedia.Free;

  if Assigned(FTrial) then
    begin
      FTrial.Free;
      FTrial := nil;
    end;

  FBackGround.Color:= FBlc.BkGnd;

  IndTrial := FCounterManager.CurrentTrial;
  if IndTrial = 0 then FFirstTrialBegin := TickCount;
  if IndTrial < FBlc.NumTrials then
    begin

      case FBlc.Trials[IndTrial].Kind of
        T_GNG : FTrial := TGNG.Create(FBackGround);
        T_MSQ : FTrial := TMSQ.Create(FBackGround);
        T_DZT : FTrial := TDZT.Create(FBackGround);
        T_CLB : FTrial := TCLB.Create(FBackGround);
        T_FPE : FTrial := TFPE.Create(FBackGround);
        T_MRD : FTrial := TMRD.Create(FBackGround);
        T_MSG : FTrial := TMessageTrial.Create(FBackGround);
        T_MTS : FTrial := TMTS.Create(FBackGround);
        T_Simple : FTrial := TSimpl.Create(FBackGround);
      end;

      if FCounterManager.Trials = 0 then
        SaveTData(FTrial.HeaderTimestamps + LineEnding);

      if Assigned(FTrial) then
        begin
          FTrial.GlobalContainer := FGlobalContainer;
          FTrial.CounterManager := FCounterManager;
          FTrial.CfgTrial := FBlc.Trials[IndTrial];
          FTrial.SaveTData := SaveTData;
          //FTrial.DoubleBuffered := True;
          FTrial.OnTrialEnd := @EndTrial;
          FTrial.OnTrialWriteData := @WriteTrialData;
          FTrial.OnStmResponse := @StmResponse;
          FTrial.OnBkGndResponse := @BkGndResponse;
          FTrial.OnHit := @Hit;
          FTrial.OnMiss := @Miss;
          FTrial.OnNone := @None;
          FTrial.Play(FIsCorrection);
        end else
          EndBlc(Self);

      FIsCorrection := False;
    end else
      begin
        if Assigned(FTrial) then
          begin
            FTrial.Free;
            FTrial := nil;
          end;
        EndBlc(Self);
      end;
end;

//todo: rewrite WriteTrialData
procedure TBlc.WriteTrialData(Sender: TObject);
var
  CountBlc,CountTr, NumTr, NameTr, ITIData, NewData, LReportLn : string;
  IsFirst : Boolean;
const
  EmptyBlock = #32#32#32#32#32#32#32#32;
  DoNotApply = #32#32#32#32#32#32 + 'NA';
begin
  if FTrial.Header <> FLastTrialHeader then
    LReportLn := FBlcHeader + 'ITIBegin' + #9 + '__ITIEnd' + #9 + FTrial.Header + LineEnding;
  FLastTrialHeader := FTrial.Header;

  //FBlcHeader:= #32#32#32#32#32#32#32#32#9 #32#32#32#32#32#32#32#32#9 #32#32#32#32#32#32#32#32#9;

  CountBlc := IntToStr(FCounterManager.CurrentBlc + 1);

  CountTr := IntToStr(FCounterManager.Trials + 1);
  NumTr:= IntToStr(FCounterManager.CurrentTrial + 1);

  // Fill Empty Names
  if FBlc.Trials[FCounterManager.CurrentTrial].Name = '' then
    NameTr := '--------'
  else NameTr := FBlc.Trials[FCounterManager.CurrentTrial].Name;

  NewData := CountBlc + #9 + FBlc.Name + #9 + CountTr + #9 + NumTr + #9 + NameTr;

  ITIData := FloatToStrF(FITIBegin - TimeStart, ffFixed,0,9) + #9 +
            FloatToStrF(FITIEND - TimeStart, ffFixed,0,9);

  // Check where it is coming from
  if Sender is TDZT then
    begin
      // Trial may not have changed, avoid repetition
      if NewData = FLastData then
        NewData := EmptyBlock + #9 + EmptyBlock + #9 +  EmptyBlock;

      // no ITI
      if FTrial.Result = '' then
        ITIData :=  DoNotApply + #9 + DoNotApply
      else
        // Check if it is the fisrt trial
        if (FCounterManager.Trials + 1) = 1 then
          IsFirst := True
        else IsFirst := False;

    end
  else
    begin

      if (FCounterManager.Trials + 1) = 1 then
        IsFirst := True
      else IsFirst := False;

    end;

  if IsFirst then
    ITIData := DoNotApply + #9 + FloatToStrF(FFirstTrialBegin - TimeStart,ffFixed,0,9);

  // write data
  LReportLn := LReportLn + NewData + #9 + ITIData + #9 + FTrial.Data + LineEnding;
  SaveData(LReportLn);
  FLastData := NewData;
  FLastITIData := ITIData;
  FTrial.Data := '';
end;

procedure TBlc.EndTrial(Sender: TObject);
var s0, s1, s2, s3, s4 : string;
    csqInterval : Integer;
    HasITI,
    HasTimeOut,
    HasCsqInterval,
    NegativeCsqInt : boolean;
    //TimestampsData : TRegData;


  procedure SetValuesToStrings (var as1, as2, as3, as4 : string);
  var
    Values : string;
  begin
    Values := '';

    // Values := FileName, HowManyLoops, Color, MediaDuration
    case FTrial.IETConsequence of
      T_HIT  : Values := 'CSQ1.wav 1 255 1';
      T_MISS : Values := 'CSQ2.wav 1 0 1';
      T_NONE : Values := 'NONE -1 -1 -1';
      else
        Values := FTrial.IETConsequence;
    end;

    s0 := Values + #32;
    as1:= FTrial.RootMedia + ExtractDelimited(1,s0,[#32]);
    as2:= ExtractDelimited(2,s0,[#32]);
    as3:= ExtractDelimited(3,s0,[#32]);
    as4:= ExtractDelimited(4,s0,[#32]);
  end;
begin
  s1 := '';
  s2 := '';
  s3 := '';
  s4 := '';
  HasITI := False;
  HasTimeOut := False;
  HasCsqInterval := False;

  if  (FTrial.NextTrial = T_END) then //end bloc
    FCounterManager.CurrentTrial := FBlc.NumTrials
  else // continue
    if (FTrial.NextTrial = T_CRT) or // FTrial.NextTrial base 1, FCounterManager.CurrentTrial.Counter base 0)
       (FTrial.NextTrial = (IntToStr(FCounterManager.CurrentTrial + 1))) then
      begin //correction trials were on
        if ((FBlc.MaxCorrection) = FCounterManager.BlcCscCorrections) and
           (FBlc.MaxCorrection <> 0) then
          begin //correction
            FCounterManager._VirtualTrialFix;
            FCounterManager.OnNotCorrection(Sender);
            FCounterManager.OnTrialEnd (Sender);
            FIsCorrection := False;
          end
        else
          begin // not correction
            FCounterManager.OnCorrection(Sender);
            FIsCorrection := True;
          end;
      end
    else  //correction trials were off
      if StrToIntDef(FTrial.NextTrial, 0) > 0 then
        begin //go to the especified trial
          if FTrial.Result = T_MISS then
            FCounterManager.VirtualTrialLoop := FCounterManager.VirtualTrialValue;

          FCounterManager.OnNotCorrection(Sender);
          FCounterManager.CurrentTrial := StrToIntDef(FTrial.NextTrial, 0) - 1;
          FCounterManager.OnNxtTrial(Sender);
          FIsCorrection := False;
        end
      else // go to the next trial,
        begin
          if FTrial.Result = T_MISS then
            FCounterManager.VirtualTrialLoop := FCounterManager.VirtualTrialValue;

          FCounterManager.OnNotCorrection(Sender);
          FCounterManager.OnTrialEnd(Sender);
          FIsCorrection := False;
        end;

  //Critérios de ACERTO atingido
  if  ((FBlc.CrtConsecutiveHit > 0) and (FBlc.CrtConsecutiveHit = FCounterManager.BlcCscHits))
   //or ((FCfgBlc.CrtConsecutiveMiss > 0) and (FCfgBlc.CrtConsecutiveMiss = FCounterManager.BlcCscMisses.Counter))
   or ((FTrial.NextTrial = IntToStr(FBlc.CrtMaxTrials)) and (FBlc.CrtMaxTrials > 0))
  then
    begin
      if Assigned(OnCriteria) then FOnCriteria(Sender);
      FCounterManager.CurrentTrial := FBlc.NumTrials
    end;


  { FileName, HowManyLoops, Color, MediaDuration }
  SetValuesToStrings(s1, s2, s3, s4);

  {
    FBlc.ITI
      negative: no ITI
      positive: play ITI
  }

  HasITI := FBlc.ITI > 0;
  if HasITI then
    FTimerITI.Interval:= FBlc.ITI
  else
    FTimerITI.Interval:= -1;

  {
    csqInterval
      negative: ignore media and subtract time from current ITI
      positive: play media then play ITI, if any
  }

  csqInterval := StrToIntDef(s4, 0);
  HasCsqInterval := (csqInterval <> 0);
  if HasCsqInterval then
    begin
      if StrToIntDef(s2, 1) > 1 then
        csqInterval := csqInterval * StrToIntDef(s2, 1);

      NegativeCsqInt := csqInterval < 0;
      if NegativeCsqInt then
        begin
          if csqInterval < FTimerITI.Interval then
            begin
              FTimerITI.Interval := FTimerITI.Interval - csqInterval;
              FTimerCsq.Interval := 0;
            end else begin
              NegativeCsqInt := False;
              HasCsqInterval := False;
            end;

        end else FTimerCsq.Interval := csqInterval;
    end else FTimerCsq.Interval := 0;
  {
    FTrial.TimeOut
      negative: no timeout
      positive: play black screen, then play ITI
  }

  HasTimeOut := FTrial.TimeOut > 0;
  if HasTimeOut then
    FBackGround.Color:= 0
  else FTrial.TimeOut := -1;

  if FTestMode then
    begin
      FTimerITI.Interval:= -1;
      FTimerTO.Interval:= -1;
      FTimerCsq.Interval:= -1;
    end;

  FITIBegin := TickCount;

  //FTrial.Hide;

  {$ifdef DEBUG}
    DebugLn(mt_Debug + '[Blc - ' + FBlc.Name + ' T - ' + IntToStr(FCounterManager.CurrentTrial)+ ']');
    DebugLn(mt_Debug + 'Timer Intervals -> ITI:' + IntToStr(FTimerITI.Interval) + ' TO:' + IntToStr(FTimerTO.Interval) + ' Csq:' + IntToStr(FTimerCsq.Interval));
  {$endif}

  if HasCsqInterval and HasTimeOut then
    begin
      raise Exception(ExceptionConfigurationNotAllowed + LineEnding +
      ' TO:' + IntToStr(FTimerTO.Interval) + ' CSQ:' + IntToStr(FTimerCsq.Interval));
      Application.Terminate;
      Exit;
    end;

  if (not HasITI) and (not HasCsqInterval) and (not HasTimeOut) then
    begin
      {$ifdef DEBUG}
        DebugLn(mt_Debug +  'Time Condition 1');
      {$endif}
      TrialTerminate(Sender);
      FITIEnd := TickCount; // Here it will be near to zero;
      PlayTrial;
      Exit;
    end;

  if HasITI and (not HasTimeOut) and (not HasCsqInterval) then
    begin // take ITI and ignore the rest
      {$ifdef DEBUG}
        DebugLn(mt_Debug +  'Time Condition 2');
      {$endif}

      //if ShowCounter then ShowCounterPlease('IET');
      FTimerITI.Enabled := True;
      FTimer.Interval := FTimerITI.Interval;
      FTimer.Enabled := FTimerITI.Enabled;
      Exit;
    end;

  if HasCsqInterval and (HasITI or (not HasITI)) then
    begin
      {$ifdef DEBUG}
        DebugLn(mt_Debug +  'Time Condition 3');
      {$endif}
      if NegativeCsqInt then
        begin
          FTimerITI.Enabled := True;
          FTimer.Interval := FTimerITI.Interval;
          FTimer.Enabled := FTimerITI.Enabled;
          Exit;
        end
      else
        begin
          CreateIETMedia(s1, s2, s3); // FileName, HowManyLoops, Color
          FTimerCsq.Enabled:= True;
          FTimer.Interval := FTimerCsq.Interval;
          FTimer.Enabled := FTimerCsq.Enabled;
          Exit;
        end
    end;

  if HasTimeOut and (HasITI or (not HasITI)) then
    begin
      {$ifdef DEBUG}
        DebugLn(mt_Debug +  'Time Condition 4');
      {$endif}

      FTimerTO.Enabled := True;
      FTimer.Interval := FTimerTO.Interval;
      FTimer.Enabled := FTimerTO.Enabled;
      Exit;
    end;

{$ifdef DEBUG}
  DebugLn(mt_Debug +  'No Time Condition');
{$endif}
end;

procedure TBlc.ClockThread(Sender: TObject);
begin
  if FTimerCsq.Enabled then
    begin
      {$ifdef DEBUG}
        DebugLn(mt_Debug +  'FTimerCsq.Enabled');
      {$endif}
      FTimerCsq.Enabled := False;

      if Assigned(FIETMedia) then
        begin
          FreeAndNil(FIETMedia);
        end;

      if (FTimerITI.Interval > 0) then
        begin
          //if ShowCounter then ShowCounterPlease('IET');
          FTimer.Interval := FTimerITI.Interval;
          FTimerITI.Enabled:= True;
          Exit;
        end
      else
        begin
          FITIEnd := TickCount;
          FTimer.Enabled := False;
          TrialTerminate(Sender);
          PlayTrial;
          Exit;
        end;
    end;

  if FTimerTO.Enabled then
    begin
      {$ifdef DEBUG}
        DebugLn(mt_Debug +  'FTimerTO.Enabled');
      {$endif}
      FTimerTO.Enabled := False;

      FBackGround.Color:= FBlc.BkGnd;

      if (FTimerITI.Interval > 0) then
        begin
          //if ShowCounter then ShowCounterPlease('IET');
          FTimer.Interval := FTimerITI.Interval;
          FTimerITI.Enabled:= True;
          Exit;
        end
      else
        begin
          FITIEnd := TickCount;
          FTimer.Enabled := False;
          TrialTerminate(Sender);
          PlayTrial;
          Exit;
        end;
    end;

  if FTimerITI.Enabled then
    begin
      {$ifdef DEBUG}
        DebugLn(mt_Debug +  'FTimerITI.Enabled');
      {$endif}

      FTimerITI.Enabled := False;

      if Assigned(FCounterLabel) then
        begin
          FCounterLabel.Free;
        end;

      FITIEnd := TickCount;
      FTimer.Enabled := False;
      TrialTerminate(Sender);
      PlayTrial;
    end;
end;

procedure TBlc.EndBlc(Sender: TObject);
begin
  SaveData(LineEnding);
  if Assigned(OnEndBlc) then FOnEndBlc(Sender);
end;

{$ifdef DEBUG}
procedure TBlc.DebugStatus(msg: string);
begin
  DebugLn(msg);
end;
{$endif}

function TBlc.GetTimeStart: Extended;
begin
  Result := FGlobalContainer.TimeStart
end;

procedure TBlc.LogEvent(ACode: string);
begin
  SaveTData(TimestampToStr(TickCount - TimeStart) + #9 +
           IntToStr(FCounterManager.CurrentBlc+1) + #9 +
           IntToStr(FCounterManager.CurrentTrial+1) + #9 +
           IntToStr(FCounterManager.Trials+1) + #9 + // Current trial cycle
           'ITI' + #32 + ACode + LineEnding)
end;

procedure TBlc.CreateIETMedia(FileName, HowManyLoops, Color: String);
//var
//  MediaPath : string;
begin
  //BlockInput(true);
  FIETMedia := TKey.Create(FBackGround);
  FIETMedia.Cursor:= FBackGround.Cursor;
  FIETMedia.Parent:= FBackGround;
  FIETMedia.OnConsequence:= @IETConsequence;
  FIETMedia.OnResponse:= @IETResponse;
  FIETMedia.Loops := StrToIntDef(HowManyLoops, 1) - 1;
  FIETMedia.Color := StrToIntDef(Color, 0);
  FIETMedia.Width := Screen.Width;
  FIETMedia.Height := Screen.Height;
  {
  FIETMedia.Width := (Screen.Width div 5) * 4;
  FIETMedia.Height := (Screen.Height div 5) * 4;
  FIETMedia.Top := (Screen.Height div 2) - (FIETMedia.Height div 2);
  FIETMedia.Left := (Screen.Width div 2) - (FIETMedia.Width div 2);
  }
  FIETMedia.FullPath := FileName;
  FIETMedia.Play;
  FIETMedia.FullScreen;
  //FTrial.IETConsequence := '';
  //FIETMedia.Show;
  if Assigned(OnConsequence) then FOnConsequence(FIETMedia);
end;


  {
procedure TBlc.ShowCounterPlease(Kind: String);
begin
  if Kind = 'IET' then
  begin
    FCounterLabel := TLabel.Create(FBackGround);
    with FCounterLabel do
    begin
      Parent:= FBackGround;
      Cursor:= FBackGround.Cursor;
      AutoSize := True;
      WordWrap := True;

      Caption := IntToStr(FCounterManager.OnHitResult);
      //Color := clBtnFace;
      Font.Size := 100;
      Font.Color := clWhite;
      Top := (Screen.Height div 2) - (Height div 2);
      Left := (Screen.Width div 2) - (Width div 2);
    end
  end;
end;   }

procedure TBlc.Hit(Sender: TObject);
begin
  FCounterManager.OnHit(Sender);
  if FBlc.CrtKCsqHit > 0 then
    if FBlc.CrtKCsqHit = FCounterManager.BlcCsqHits then       //Procedimento da Ana Paula, acertos consecutivos produzindo csq
      begin
        FCounterManager.OnCsqCriterion(Sender);
        //FTrial.DispenserPlusCall;
      end;
  if Assigned(OnHit) then FOnHit(Sender);
end;

procedure TBlc.IETResponse(Sender: TObject);
begin
  BkGndResponse(Sender);
end;

procedure TBlc.IETKeyUp(Sender: TObject; var Key: Word; Shift: TShiftState);
begin
  if key = 32 then
    LogEvent('R');
end;

procedure TBlc.Miss(Sender: TObject);
begin
  FCounterManager.OnMiss(Sender);
  if Assigned(OnMiss) then FOnMiss(Sender);
end;

procedure TBlc.IETConsequence(Sender: TObject);
begin
  //
end;

procedure TBlc.None(Sender: TObject);
begin
  //
end;

procedure TBlc.BkGndResponse(Sender: TObject);
begin
  if Assigned(OnBkGndResponse) then FOnBkGndResponse(Sender);
end;


procedure TBlc.StmResponse(Sender: TObject);
begin
  if Assigned(OnStmResponse) then FOnStmResponse (Sender);
end;

procedure TBlc.TrialTerminate(Sender: TObject);
begin
  if Assigned(OnTrialEnd) then FOnTrialEnd(Sender);
end;


end.

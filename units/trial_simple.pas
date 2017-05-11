{
  Stimulus Control
  Copyright (C) 2014-2017 Carlos Rafael Fernandes Picanço, Universidade Federal do Pará.

  The present file is distributed under the terms of the GNU General Public License (GPL v3.0).

  You should have received a copy of the GNU General Public License
  along with this program. If not, see <http://www.gnu.org/licenses/>.
}
unit trial_simple;

{$mode objfpc}{$H+}

interface

uses LCLIntf, LCLType, Controls, Classes, SysUtils, LazFileUtils

    , response_key
    , trial_abstract
    //, countermanager
    //, config_session
    //, counter
    //, interface_rs232
    //, interface_plp
    ;

type

  { Testing and refactoring required }

  TSupportKey = record
    Key : TKey; // response key
    Csq : BYTE; // PLP consequence
    Usb : string; // USB consequence
    Msg : string; // Report Message
    Nxt : string; // Next Trial
    Res : string; // Trial Result: MISS, NONE or HIT.
    IET : string; // Intertrial interval
    TO_ : Integer; // Timeout consequence
  end;

  TDataSupport = record
    BackgroundResponseCount : integer;
    Latency,
    StmBegin,
    StmEnd : Extended;
    CompMsg,
    Rs232Code : string;
    PLPCode : BYTE;
  end;

  { TSimpl }

  TSimpl = Class(TTrial)
  private
    procedure Consequence(Sender: TObject);
    procedure Dispenser(Csq: Byte; Usb: string);
    procedure Response(Sender: TObject);
    procedure TrialBeforeEnd(Sender: TObject);
  protected
    FDataSupport : TDataSupport;
    FConsequenceFired : Boolean;
    FNumComp : Integer;
    FTrialInterval : Integer;
    FComparisons : array of TSupportKey;
    procedure TrialStart(Sender: TObject); virtual;
    procedure WriteData(Sender: TObject); override;
    procedure TrialResult(Sender: TObject);
    procedure VisibleComparisons(AValue: Boolean);
    procedure ComparisonMouseDown(Sender: TObject;Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
  public
    constructor Create(AOwner: TComponent); override;
    procedure Play(ACorrection : Boolean); override;
  end;

implementation

uses strutils, constants, timestamps;

constructor TSimpl.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  OnTrialBeforeEnd := @TrialBeforeEnd;
  OnTrialStart := @TrialStart;

  Header :=  Header +
             'Pos.Cmp.' + #9 + // Msg of each stimulus
             'Res.Cmp.' + #9 + // Msg of the stimulus that have ended the trial
             'Lat.Cmp.' + #9 + // Latency
             'Dur.Cmp.' + #9 + // presentation time of all stimuli
             '___Disp.' + #9 + // RS232 code of the stimulus that have ended the trial
             '___UDsp.' + #9 + // USB code of the stimulus that have ended the trial
             'Frq.Cmp.';       // absolute response frequency from each stimulus

  HeaderTimestamps := HeaderTimestamps + #9 +
                      'Lft.Cmp.' + #9 +
                      'Top.Cmp.';              // top left of all clicks

end;

procedure TSimpl.Dispenser(Csq: Byte; Usb: string);
begin
  //PLP.OutPortOn (Csq);
  //RS232.Dispenser(Usb);
end;

procedure TSimpl.Play(ACorrection: Boolean);
var
  s1 : string;
  R : TRect;
  I : Integer;
begin
  inherited Play(ACorrection);

  FNumComp := StrToIntDef(CfgTrial.SList.Values[_NumComp], 0);
  SetLength(FComparisons, FNumComp);
  for I := 0 to FNumComp-1 do
    with FComparisons[I] do
      begin
        Key := TKey.Create(Self);
        Key.Tag := I;
        Key.Cursor := Self.Cursor;
        Key.OnConsequence := @Consequence;
        Key.OnResponse := @Response;
        Key.Schedule.Kind := CfgTrial.SList.Values[_Comp + IntToStr(I + 1) + _cSch];
        AddToClockList(Key.Schedule);
        Key.Parent := TCustomControl(Self.Parent);

        s1 := CfgTrial.SList.Values[_Comp + IntToStr(I + 1) + _cBnd] + #32;
        R.Top := StrToIntDef(ExtractDelimited(1,s1,[#32]),0);
        R.Left := StrToIntDef(ExtractDelimited(2,s1,[#32]),0);
        R.Bottom := StrToIntDef(ExtractDelimited(3,s1,[#32]),100);
        R.Right := StrToIntDef(ExtractDelimited(4,s1,[#32]),100);
        Key.SetBounds(R.Left, R.Top, R.Right, R.Bottom);

        s1 := CfgTrial.SList.Values[_Comp + IntToStr(I + 1) + _cStm] + #32;
        Key.FullPath := RootMedia + ExtractDelimited(1,s1,[#32]);
        Key.Loops:= StrToIntDef(ExtractDelimited(2,s1,[#32]),0);
        Key.Color := StrToIntDef(ExtractDelimited(3,s1,[#32]), $0000FF); //clRed

        Csq := StrToIntDef(CfgTrial.SList.Values[_Comp + IntToStr(I + 1) + _cCsq], 0);
        //Usb := CfgTrial.SList.Values[_Comp+IntToStr(I+1)+_cUsb];
        Msg := CfgTrial.SList.Values[_Comp + IntToStr(I + 1) + _cMsg];
        Res := CfgTrial.SList.Values[_Comp + IntToStr(I + 1) + _cRes];
        Nxt := CfgTrial.SList.Values[_Comp + IntToStr(I + 1) + _cNxt];
        TO_ := StrToIntDef(CfgTrial.SList.Values[_Comp + IntToStr(I + 1) + _cTO], 0);
        IET := CfgTrial.SList.Values[_Comp + IntToStr(I + 1) + _cIET];
      end;

  if Self.ClassType = TSimpl then Config(Self);
end;

procedure TSimpl.TrialResult(Sender: TObject);
var i : integer;
begin
  FDataSupport.StmEnd := TickCount;
  FResponseEnabled:= False;

  if Sender is TKey then
    begin
      i := TKey(Sender).Tag;
      //FDataSupport.PLPCode:= FComparisons[i].Csq;
      //FDataSupport.RS232Code := FComparisons[i].Usb;
      TimeOut := FComparisons[i].TO_;
      IETConsequence := FComparisons[i].IET;

      case FComparisons[i].Res of
        T_HIT : Result := T_HIT;
        T_MISS : Result := T_MISS;
      else
        Result := T_NONE;
      end;

      if FComparisons[i].Nxt = T_CRT then
        NextTrial := T_CRT
      else
        NextTrial := FComparisons[i].Nxt;

      case FComparisons[i].Msg of
        '','AUTO' : FDataSupport.CompMsg := TKey(Sender).ShortName+' - '+'('+IntToStr(TKey(Sender).Top)+','+IntToStr(TKey(Sender).Left)+')';
        else
          FDataSupport.CompMsg:= FComparisons[i].Msg;
      end;
    end;
end;

procedure TSimpl.VisibleComparisons(AValue: Boolean);
var i : integer;
begin
  for i := Low(FComparisons) to High(FComparisons) do
  begin
    FComparisons[i].Key.Schedule.Enabled := AValue;
    FComparisons[i].Key.Visible := AValue;
  end;
end;

procedure TSimpl.TrialStart(Sender: TObject);
begin
  VisibleComparisons(True);

  with FDataSupport do
    begin
      Latency := TimeStart;
      StmEnd := TimeStart;
    end;

  FDataSupport.StmBegin := TickCount;
  OnMouseDown := @ComparisonMouseDown;
end;

procedure TSimpl.WriteData(Sender: TObject);
var
  Pos_Cmp,
  Lat_Cmp,
  Dur_Cmp,
  Res_Cmp,
  Disp,
  uDisp,
  Frq_Cmp: string;

  I : Integer;
begin
  Frq_Cmp := '';
  Pos_Cmp := '';
  Disp := '';
  uDisp := '';
  for I := 0 to High(FComparisons) do
      Frq_Cmp := Frq_Cmp + FComparisons[I].Msg + '=' +
                                   IntToStr(FComparisons[I].Key.ResponseCount) + #9;
  Frq_Cmp := Frq_Cmp + 'BK.C='+ IntToStr(FDataSupport.BackgroundResponseCount);

  for I:= 0 to FNumComp-1 do
    begin
      if FComparisons[I].Msg = '' then FComparisons[I].Msg:= '-';
      Pos_Cmp:= Pos_Cmp + FComparisons[I].Msg + #32;
    end;

  { todo: separate the comparison message from the GONOGO logic }
  if FDataSupport.CompMsg = '' then FDataSupport.CompMsg:= '-';
  Res_Cmp:= LeftStr(FDataSupport.CompMsg+#32#32#32#32#32#32#32#32, 8);

  if FDataSupport.Latency = TimeStart then
    Lat_Cmp := #32#32#32#32#32#32 + 'NA'
  else Lat_Cmp := TimestampToStr(FDataSupport.Latency - TimeStart);
  Dur_Cmp := TimestampToStr(FDataSupport.StmEnd - FDataSupport.StmBegin);

  //Disp:= RightStr(IntToBin(FDataSupport.PLPCode, 9)+#0, 8);
  //uDisp := IntToStr(FDataSupport.RS232Code);

  Data := Data +
          Pos_Cmp + #9 +
          Res_Cmp + #9 +
          Lat_Cmp + #9 +
          Dur_Cmp + #9 +
          Disp    + #9 +
          uDisp   + #9 +
          Frq_Cmp;

  if Assigned(OnTrialWriteData) then OnTrialWriteData(Self);
end;

procedure TSimpl.ComparisonMouseDown(Sender: TObject; Button: TMouseButton;
  Shift: TShiftState; X, Y: Integer);
begin
  LogEvent('BK.C' + #9 + IntToStr(X) + #9 + IntToStr(Y));
  Inc(FDataSupport.BackgroundResponseCount); // local
  CounterManager.OnBkgndResponse(Self); // global
  if Assigned(OnBkGndResponse) then OnBkGndResponse(Self);
end;

procedure TSimpl.TrialBeforeEnd(Sender: TObject);
begin
  TrialResult(Sender);
  WriteData(Sender);
end;

procedure TSimpl.Consequence(Sender: TObject);
begin
  if not FConsequenceFired then
    FConsequenceFired := True;

  { todo: The Dispenser requires working interfaces. They were not tested in the cross platform scope. }
  Dispenser(FDataSupport.PLPCode, FDataSupport.RS232Code);
  CounterManager.OnConsequence(Sender);
  if Assigned(OnConsequence) then OnConsequence(Sender);
  EndTrial(Sender);
end;

procedure TSimpl.Response(Sender: TObject);
begin
  if Sender is TKey then
    if TKey(Sender).Visible then
      begin
        LogEvent(FComparisons[TKey(Sender).Tag].Msg + #9 + TKey(Sender).LastResponseLog);

        if FDataSupport.Latency = TimeStart then
          FDataSupport.Latency := TickCount;

        if Assigned(CounterManager.OnStmResponse) then CounterManager.OnStmResponse(Sender);
        if Assigned(OnStmResponse) then OnStmResponse (Self);
      end;
end;



end.

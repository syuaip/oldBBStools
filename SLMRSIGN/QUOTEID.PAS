{$A+,B-,D-,E-,F-,I+,L-,N-,O-,R-,S-,V-}
{$M 65520,0,655360}

program get_quoting_id_versi_satu_final;

{
  Changes:
  - Header data is grabbed from file CONTROL.DAT too..
    Not only from REPLY.MSG anymore
  - User defined sign delimiter
    Not just # anymore
}

Uses Dos, Crt;

function trim(st: string) : string;
begin
  while (st[0] > #0) and (st[length(st)] = #32) do st[0] := chr(ord(st[0])-1);
  while (st[0] > #0) and (st[1] = #32) do delete(st,1,1);
  trim := st;
end;

function upstr(st : string) : string;
var x : byte;
begin
  if length(st) > 0 then
    for x := 1 to length(st) do
      st[x] := upcase(st[x]);
  upstr := st;
end;

function dncase(ch : char) : char;
begin
  if ch IN ['A'..'Z'] then ch := chr(ord(ch) + $20);
  dncase := ch;
end;

function dnstr(st : string) : string;
var x : byte;
begin
  if length(st) > 0 then
    for x := 1 to length(st) do
      st[x] := dncase(st[x]);
  dnstr := st;
end;

function firstcharup(st : string) : string;
var x : byte;
begin
  if length(st) > 0 then
    for x := 1 to length(st) do
      if ((st[x-1] = #32) AND (x >= 2) OR (x=1)) then
         st[x] := upcase(st[x])
      else
         st[x] := dncase(st[x]);
  firstcharup := st;
end;

function backward(st : string) : string;
var c : byte; t : string;
begin
  t[0] := chr(length(st));
     For c := 1 to length(st) do t[c] := st[length(st)+1-c];
  backward := T;
end;

function firsttoken(st : string; c : char) : string;
var x : byte;
begin
  x := pos(c,st);
  if x > 0 then firsttoken := copy(st,1,x-1)
    else firsttoken := st;
end;

function lasttoken(st : string; c : char) : string;
var x : byte;
begin
  st := backward(st);
  x := pos(c,st);
  if x > 0 then lasttoken := backward(copy(st,1,x-1))
    else lasttoken := backward(st);
end;

function SelfDir : String;
var D, N, E : String;
begin
   FSplit(ParamStr(0),D,N,E);
   If D[Length(D)] <> '\' then D := D + '\';
   SelfDir := D;
end;

const
    id         = 'Header Quoting Tool for SLMR 2.1a';
    versi      = 'V.1.1 - by Mirage';
    inifile    = 'QUOTEID.INI';

type
    str80      = string[80];
    str27      = string[27];
    tRawHeader = array[0..6] of str80;
    tHeaderID  = object
                    isBBS,
                    isDate,
                    isTime,
                    isFrom,
                    isTo,
                    isSubj,
                    isConf,
                    isOwner,
                    isNumber   : str27;
                    ibRecvd,
                    ibPrivate  : boolean;
                    function  Init(var RawHead : tRawHeader; Owner : String) : boolean;
                    function  sBBS     : str27;
                    function  sDate    : str27;
                    function  sTime    : str27;
                    function  sFrom    : str27;
                    function  sTo      : str27;
                    function  sSubj    : str27;
                    function  sConf    : str27;
                    function  sOwner   : str27;
                    function  sNumber  : str27;
                    function  bRecvd   : boolean;
                    function  bPrivate : boolean;
                 end;

function tHeaderID.Init;
begin
  If RawHead[0,1] <> '=' then
    Init := false  { _^_ cek apa ini formatnya REPLY.MSG }
  else
    Begin
      isBBS     := Trim(Copy(RawHead[1], 7,28));
      isDate    := Trim(Copy(RawHead[2], 7, 8));
      isTime    := Trim(Copy(RawHead[2],17, 5));
      isNumber  := Trim(Copy(RawHead[2],44,10));  { dilebihkan }
      isOwner   := Trim(Owner);
      isFrom    := Trim(Copy(RawHead[3], 7,28));
      isTo      := Trim(Copy(RawHead[4], 7,28));
      isSubj    := Trim(Copy(RawHead[5], 7,28));
      isConf    := Trim(Copy(RawHead[5],44,28));
      ibRecvd   := Copy(RawHead[4],44, 3) = 'YES';
      ibPrivate := Copy(RawHead[4],49, 3) = 'PVT';
      Init := true;
    End;
end;

function tHeaderID.sBBS;
begin
  sBBS := isBBS;
end;

function tHeaderID.sDate;
begin
  sDate := isDate;
end;

function tHeaderID.sTime;
begin
  sTime := isTime;
end;

function tHeaderID.sFrom;
begin
  sFrom := isFrom;
end;

function tHeaderID.sTo;
begin
  sTo := isTo;
end;

function tHeaderID.sSubj;
begin
  sSubj := isSubj;
end;

function tHeaderID.sConf;
begin
  sConf := isConf;
end;

function tHeaderID.sNumber;
begin
  sNumber := isNumber;
end;

function tHeaderID.sOwner;
begin
  sOwner := isOwner;
end;

function tHeaderID.bRecvd;
begin
  bRecvd := ibRecvd;
end;

function tHeaderID.bPrivate;
begin
  bPrivate := ibPrivate;
end;

type
    tApplication = object(tHeaderID)
                     Delimiter   : char;
                     RawHeader   : tRawHeader;
                     SenderID    : String;
                     QuoteStr    : String;
                     SignStr     : String;
                     function readINIfile : boolean;
                     function  translated(st : string) : string;
                  end;

{
   Function
   --------
   #1()#      = First Char UpCase
   #U()#      = String on UpperCase
   #L()#      = String on LowerCase
   #IN(,,)#   = Get Status if name on 'From' is internet@address.la.yaw

   #N#        = New Line
   #D#        = Date
   #TI#       = Time
   #F#        = From
   #FF#       = From (First Name)
   #FL#       = From (Last Name)
   #IFFROM#   = From (username on internet address)
   #IADDR#    = From (domainname on internet address)
   #O#        = Owner of SMLR
   #OF#       = Owner (First Name)
   #OL#       = Owner (Last Name)
   #T#        = To
   #TF#       = To (First Name)
   #TL#       = To (Last Name)
   #S#        = Subject

}

function sum(c : char; s : string) : byte;
var p, q : byte;
begin
  q := 0;
  if length(s) > 0 then begin
       for p := 1 to length(s) do
          if (s[p] = c) then inc(q);
    end;
  sum := q;
end;

const
  functionarray : array[1..16] of string[16] =
                   (
                      'N'      , { New Line }
                      'D'      , { Date }
                      'TI'     , { Time }
                      'F'      , { From }
                      'FF'     , { From (First Name) }
                      'FL'     , { From (Last Name) }
                      'IFFROM' , { From (username on internet address) }
                      'IADDR'  , { From (domainname on internet address) }
                      'T'      , { To }
                      'TF'     , { To (First Name) }
                      'TL'     , { To (Last Name) }
                      'C'      , { Conference }
                      'S'      , { Subject }
                      'O'      , { Owner }
                      'OF'     , { Owner (First Name) }
                      'OL'     );{ Owner (Last Name) }

{ #S1#  UpperCase All
  #S2#  LowerCase All
  #S3#  UpperCase on the first letter of every word
}

function tApplication.Translated;
const tempchar  : char = '`';
      ATsign    : char = '@';
var x1, x2, x3, y : byte; s, s2 : string;
begin
  if length(st) > 0 then
    begin
      while sum(delimiter,st) > 1 do
        begin
           x1     := pos(delimiter,st);
           st[x1] := tempchar;
           x2     := pos(delimiter,st);
           if (x2 > 0) then
              begin
                s := copy(st,x1+1,(x2-x1)-1);
                st[x2] := tempchar;
       {         writeln(s); }

                if (s = functionarray[01]) then s2 := #13#10 else
                 if (s = functionarray[02]) then s2 := sDate  else
                  if (s = functionarray[03]) then s2 := sTime  else
                   if (s = functionarray[04]) then s2 := sFrom  else
                    if (s = functionarray[05]) then s2 := FirstToken(sFrom,#32) else
                     if (s = functionarray[06]) then s2 := LastToken(sFrom,#32)  else
                      if (s = functionarray[07]) then s2 := FirstToken(sFrom,ATsign) else
                       if (s = functionarray[08]) then s2 := LastToken(sFrom,ATsign) else
                        if (s = functionarray[09]) then s2 := sTo    else
                         if (s = functionarray[10]) then s2 := FirstToken(sTo,#32) else
                          if (s = functionarray[11]) then s2 := LastToken(sTo,#32) else
                           if (s = functionarray[12]) then s2 := sConf else
                            if (s = functionarray[13]) then s2 := sSubj else
                             if (s = functionarray[14]) then s2 := sOwner    else
                              if (s = functionarray[15]) then s2 := FirstToken(sOwner,#32) else
                               if (s = functionarray[16]) then s2 := LastToken(sOwner,#32) else
                                   s2 := tempchar;

             {    writeln(s2); }
                 if s2 <> tempchar then
                    begin
                       delete(st,x1,x2-x1+1);
                       insert(s2,st,x1);
                    end
              end
           else
              translated := 'InternalError:There''s no more delimiter found!';
        end;
    end;
  translated := st;
end;

procedure GetRawHeader(var parRawheader : tRawHeader; var sSenderID : String);
var fr : text;
begin
  {$I-}
  assign(fr,'REPLY.MSG');
  reset(fr);
    if ioresult <> 0 then ;

  readln(fr,parRawHeader[0]);
  readln(fr,parRawHeader[1]);
  readln(fr,parRawHeader[2]);
  readln(fr,parRawHeader[3]);
  readln(fr,parRawHeader[4]);
  readln(fr,parRawHeader[5]);
  readln(fr,parRawHeader[6]);

  close(fr);
    if ioresult <> 0 then writeln('Error:GetRawHeader');

  assign(fr,'CONTROL.DAT');
  reset(fr);
    if ioresult <> 0 then ;

  readln(fr,sSenderID);
  readln(fr,sSenderID);
  readln(fr,sSenderID);
  readln(fr,sSenderID);
  readln(fr,sSenderID);
  readln(fr,sSenderID);
  readln(fr,sSenderID);

  close(fr);
    if ioresult <> 0 then writeln('Error:GetRawHeader');
  {$I+}
end;

{
RED BLOCK BBS
JAKARTA SELATAN
+062-021-740-2130
TEGUH IMAN, Sysop
00000,REDBLOCK
02-18-1996,18:01:00
ARIEF W NUGRAHA
}

function tApplication.readINIfile : Boolean;
var fhnd : text; s1, s2 : string;
Begin
  {$I-}
  Assign(FHnd,SelfDir+IniFile);
  Reset(FHnd);
    if ioresult <> 0 then begin readinifile := false; exit; end;
  repeat
     readln(FHnd,S1);
     If (S1 <> '') AND (S1[1] <> '@') then
        begin
          S2 := FirstToken(S1,'=');
          Delete(S1,1,Pos('=',S1));
          If (UpStr(S2) = 'QUOTE') AND (S1 <> '') then QuoteStr := S1 else
            If (UpStr(S2) = 'SIGN') AND (S1 <> '') then SignStr := S1 else
            If (UpStr(S2) = 'DELIMITER') AND (S1 <> '') then Delimiter := S1[1];
        end;
  until EOF(FHnd);
  close(FHnd);
  {$I+}
  readINIfile := IOResult = 0;
End;

var Application : tApplication;
    fri, fro : text; f : file;
    stmp : string;

begin
  If (ParamCount = 0) OR (POS('/?',ParamStr(1)) > 0) then
     Begin
       WriteLn(id+' - '+versi+#10);
       WriteLn('This program is used to create quoting header and');
       WriteLn('user sign on mail edited by SLMR 2.1a.');
       WriteLn('Please read QUOTEID.DOC for more information.'#10);
       Write('Press any key...');
       stmp[1] := ReadKey;
       WriteLn;
       exit;
      End
   else

  With Application do
    Begin

      isBBS      := '(BBS Name)';
      isDate     := '99-99-99';
      isTime     := '99:99';
      isFrom     := 'SOMEONE';
      isTo       := 'ALL';
      isSubj     := '(Subject)';
      isConf     := '(Conf. Name)';
      isNumber   := '88888888';
      ibRecvd    := False;
      ibPrivate  := True;
      Delimiter  := '#';

      If NOT ReadINIfile then
        Begin
          QuoteStr := '<<--- Quoting #F# to #T# on #D#/#TI# about #S# --->>';
          SignStr  := 'See you next time, #FF# !';
        End;
      If (FSearch('REPLY.MSG','') <> '' ) then Begin
            GetRawHeader(RawHeader,SenderID);
            If Init(RawHeader,SenderID) then Begin
                {$I-}
                assign(fri,'REPLY.MSG');
                reset(fri);
                  if ioresult <> 0 then writeln('Error:resetREPLY.MSG');

                assign(fro,'REPLY.TMP');
                rewrite(fro);

                writeLn(fro,Translated(QuoteStr));

                readln(fri,stmp);
                readln(fri,stmp);
                readln(fri,stmp);
                readln(fri,stmp);
                readln(fri,stmp);
                readln(fri,stmp);
                readln(fri,stmp);

                writeln(fro);

                while not eof(fri) do begin
                     readln(fri,stmp);
                     writeln(fro,stmp);
                end;

                writeLn(fro,Translated(SignStr));

                close(fri);
                  if ioresult <> 0 then writeln('Error:closeREPLY.MSG');
                close(fro);
                  if ioresult <> 0 then writeln('Error:closeREPLY.TMP');

                assign(f,'REPLY.MSG');
                erase(f);
                  if ioresult <> 0 then writeln('Error:eraseREPLY.TMP');

                assign(f,'REPLY.TMP');
                rename(f,'REPLY.MSG');
                  if ioresult <> 0 then writeln('Error:renameREPLY.TMP');
            End
      end
        else
      begin
        assign(fro,'REPLY.MSG');
        rewrite(fro);
        writeLn(fro,Translated(QuoteStr));
        writeln(fro);
        writeLn(fro,Translated(SignStr));
        close(fro);
        if ioresult <> 0 then writeln('Error:writeREPLY.TMP');
        {$I+}
      end;
    end;
end.

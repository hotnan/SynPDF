/// wrapper around FPC typinfo.pp unit for SynCommons.pas and mORMot.pas
unit SynFPCTypInfo;

{
    This file is part of Synopse mORMot framework.

    Synopse mORMot framework. Copyright (C) 2017 Arnaud Bouchez
      Synopse Informatique - https://synopse.info

  *** BEGIN LICENSE BLOCK *****
  Version: MPL 1.1/GPL 2.0/LGPL 2.1

  The contents of this file are subject to the Mozilla Public License Version
  1.1 (the "License"); you may not use this file except in compliance with
  the License. You may obtain a copy of the License at
  http://www.mozilla.org/MPL

  Software distributed under the License is distributed on an "AS IS" basis,
  WITHOUT WARRANTY OF ANY KIND, either express or implied. See the License
  for the specific language governing rights and limitations under the License.

  The Original Code is Synopse mORMot framework.

  The Initial Developer of the Original Code is Alfred Glaenzer.

  Portions created by the Initial Developer are Copyright (C) 2017
  the Initial Developer. All Rights Reserved.

  Contributor(s):
  - Arnaud Bouchez


  Alternatively, the contents of this file may be used under the terms of
  either the GNU General Public License Version 2 or later (the "GPL"), or
  the GNU Lesser General Public License Version 2.1 or later (the "LGPL"),
  in which case the provisions of the GPL or the LGPL are applicable instead
  of those above. if you wish to allow use of your version of this file only
  under the terms of either the GPL or the LGPL, and not to allow others to
  use your version of this file under the terms of the MPL, indicate your
  decision by deleting the provisions above and replace them with the notice
  and other provisions required by the GPL or the LGPL. if you do not delete
  the provisions above, a recipient may use your version of this file under
  the terms of any one of the MPL, the GPL or the LGPL.

  ***** END LICENSE BLOCK *****


  Version 1.18
  - initial revision

}

interface

{$I Synopse.inc} // define HASINLINE USETYPEINFO CPU32 CPU64 OWNNORMTOUPPER

uses
  SysUtils,
  TypInfo;

const
  ptField = 0;
  ptStatic = 1;
  ptVirtual = 2;
  ptConst = 3;

{$ifdef FPC_REQUIRES_PROPER_ALIGNMENT}
function AlignToPtr(p : pointer): pointer; inline;
function GetFPCAlignPtr(P: pointer): pointer; inline;
{$else FPC_REQUIRES_PROPER_ALIGNMENT}
type
  AlignToPtr = pointer;
{$endif FPC_REQUIRES_PROPER_ALIGNMENT}

function GetFPCEnumName(TypeInfo: PTypeInfo; Value: Integer): PShortString; inline;
function GetFPCEnumValue(TypeInfo: PTypeInfo; const Name: string): Integer; inline;
Function AlignTypeData(p : Pointer) : Pointer;
function GetFPCTypeData(TypeInfo: PTypeInfo): PTypeData; inline;
function GetFPCPropInfo(AClass: TClass; const PropName: string): PPropInfo; inline;
{$ifdef FPC_NEWRTTI}
function GetFPCRecInitData(TypeData: Pointer): Pointer; inline;
{$endif}


implementation

{$ifdef FPC_REQUIRES_PROPER_ALIGNMENT}
function AlignToPtr(p : pointer): pointer; inline;
begin
  result := align(p,sizeof(p));
end;
{$endif}

function GetFPCEnumValue(TypeInfo: PTypeInfo; const Name: string): Integer;
var PS: PShortString;
    PT: PTypeData;
    Count: longint;
    sName: shortstring;
begin
  if Length(Name)=0 then
    exit(-1);
  sName := Name;
  PT := GetFPCTypeData(TypeInfo);
  Count := 0;
  Result := -1;

  if TypeInfo^.Kind=tkBool then begin
    if CompareText(BooleanIdents[false],Name)=0 then
      result := 0 else
    if CompareText(BooleanIdents[true],Name)=0 then
      result := 1;
  end else
  begin
    PS := @PT^.NameList;
    while (Result=-1) and (PByte(PS)^<>0) do begin
        if ShortCompareText(PS^, sName) = 0 then
          Result := Count+PT^.MinValue;
        PS := PShortString(pointer(PS)+PByte(PS)^+1);
        Inc(Count);
      end;
  end;
end;

function GetFPCEnumName(TypeInfo: PTypeInfo; Value: Integer): PShortString;
const NULL_SHORTSTRING: string[1] = '';
Var PS: PShortString;
    PT: PTypeData;
begin
  PT := GetFPCTypeData(TypeInfo);
  if TypeInfo^.Kind=tkBool then begin
    case Value of
      0,1: Result := @BooleanIdents[Boolean(Value)];
      else Result := @NULL_SHORTSTRING;
    end;
  end else begin
    PS := @PT^.NameList;
    dec(Value,PT^.MinValue);
    while Value>0 do begin
      PS := PShortString(pointer(PS)+PByte(PS)^+1);
      Dec(Value);
    end;
    Result := PS;
  end;
end;

Function AlignTypeData(p : Pointer) : Pointer;
{$push}
{$packrecords c}
  type
    TAlignCheck = record
      b : byte;
      q : qword;
    end;
{$pop}
begin
{$ifdef FPC_REQUIRES_PROPER_ALIGNMENT}
{$ifdef VER3_0}
  Result:=Pointer(align(p,SizeOf(Pointer)));
{$else VER3_0}
  Result:=Pointer(align(p,PtrInt(@TAlignCheck(nil^).q)))
{$endif VER3_0}
{$else FPC_REQUIRES_PROPER_ALIGNMENT}
  Result:=p;
{$endif FPC_REQUIRES_PROPER_ALIGNMENT}
end;

function GetFPCTypeData(TypeInfo: PTypeInfo): PTypeData;
begin
  result := PTypeData(AlignTypeData(PTypeData(pointer(TypeInfo)+2+PByte(pointer(TypeInfo)+1)^)));
end;

{$ifdef FPC_REQUIRES_PROPER_ALIGNMENT}

function GetFPCAlignPtr(P: pointer): pointer;
begin
  result := AlignTypeData(P+2+Length(PTypeInfo(P)^.Name));
  Dec(PtrUInt(result),SizeOf(pointer));
end;

{$endif}

{
procedure getMethodList(aClass:TClass);
Type PMethodEntry=^TMethodEntry;
     TMethodEntry=packed record
       size:Word;
       Adr:pointer;
       Name:Shortstring;
     end;
var mTable:ppointer;
    ClassName:String;
    MethodCount:PWord;
    MethodEntry:PMethodEntry;
    i:integer;
begin
  while aClass<>nil do
  begin
    mTable := pointer(integer(aClass)+vmtMethodTable);
    if (mTable<>nil)and(mTable^<>nil) then
    begin
      MethodCount := mTable^;
      MethodEntry := pointer(integer(MethodCount)+2);
      ClassName := aClass.ClassName;
      for i := 1 to MethodCount^ do
      begin
        writeln(MethodEntry^.Name);
        MethodEntry := pointer(integer(MethodEntry)+MethodEntry^.size);
      end;
    end;
    aClass := aClass.ClassParent;
  end;
end;
}

function GetFPCPropInfo(AClass: TClass; const PropName: string): PPropInfo;
begin
  result := typinfo.GetPropInfo(AClass,PropName);
end;

{$ifdef FPC_NEWRTTI}
function GetFPCRecInitData(TypeData: Pointer): Pointer;
begin
  if PTypeData(TypeData)^.RecInitInfo = nil then
    result := TypeData
  else
    result := AlignTypeData(pointer(PTypeData(TypeData)^.RecInitData));
end;
{$endif}

end.

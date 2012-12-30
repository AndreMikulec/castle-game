{
  Copyright 2006-2012 Michalis Kamburelis.

  This file is part of "castle".

  "castle" is free software; you can redistribute it and/or modify
  it under the terms of the GNU General Public License as published by
  the Free Software Foundation; either version 2 of the License, or
  (at your option) any later version.

  "castle" is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
  GNU General Public License for more details.

  You should have received a copy of the GNU General Public License
  along with "castle"; if not, write to the Free Software
  Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA

  ----------------------------------------------------------------------------
}

{ }
unit GameCreatures;

interface

uses Classes, VectorMath, PrecalculatedAnimation, CastleClassUtils, CastleUtils,
  CastleScene, CastleResources, CastleXMLConfig, Base3D, X3DNodes,
  CastleCreatures;

type
  TWerewolfKind = class(TWalkAttackCreatureKind)
  public
    function CreatureClass: TCreatureClass; override;
  end;

  TGhostKind = class(TWalkAttackCreatureKind)
  public
    function CreatureClass: TCreatureClass; override;
  end;

  TWerewolfCreature = class(TWalkAttackCreature)
  private
    NextHowlTime: Single;
  public
    constructor Create(AOwner: TComponent; const AMaxLife: Single); override;
    procedure Idle(const CompSpeed: Single; var RemoveMe: TRemoveType); override;
    procedure Howl(ForceHowl: boolean);
  end;

  TGhostCreature = class(TWalkAttackCreature)
  protected
    procedure SetState(Value: TCreatureState); override;
  end;

var
  Werewolf: TWerewolfKind;
  Ghost: TGhostKind;
  Spider: TWalkAttackCreatureKind;
  SpiderQueen: TWalkAttackCreatureKind;
  Arrow: TMissileCreatureKind;

procedure CreaturesKindsInit;

implementation

uses SysUtils, DOM, GL, GLU, CastleWindow, CastleFilesUtils, CastleGLUtils,
  ProgressUnit, GameSound;

{ TWerewolfKind -------------------------------------------------------------- }

function TWerewolfKind.CreatureClass: TCreatureClass;
begin
  Result := TWerewolfCreature;
end;

{ TGhostKind ------------------------------------------------------------- }

function TGhostKind.CreatureClass: TCreatureClass;
begin
  Result := TGhostCreature;
end;

{ TWerewolfCreature ---------------------------------------------------------- }

constructor TWerewolfCreature.Create(AOwner: TComponent; const AMaxLife: Single);
begin
  inherited;
  NextHowlTime := Random * 60.0;
end;

procedure TWerewolfCreature.Idle(const CompSpeed: Single; var RemoveMe: TRemoveType);
begin
  inherited;
  if (not GetExists) or DebugTimeStopForCreatures then Exit;

  if (not Dead) and (LifeTime > NextHowlTime) then
    Howl(false);
end;

procedure TWerewolfCreature.Howl(ForceHowl: boolean);
begin
  { Howl only if player was seen, and only while walking/standing
    (not in the middle of attack e.g., since that would sound stupid). }
  if ForceHowl or (HasLastSeenEnemy and (State in [csWalk, csIdle])) then
    Sound3d(stWerewolfHowling, 1.0);

  { Whether you actually howled or not, schedule next howl. }
  NextHowlTime := LifeTime + Random * 60.0;
end;

{ TGhostCreature ---------------------------------------------------------- }

procedure TGhostCreature.SetState(Value: TCreatureState);
begin
  inherited;

  { Ghosts dead animation is quite unique, so we will not check
    collisions with ghost when it's in dying state.
    Ghost is blended anyway, so checking for collisions with him
    is not really necessary anyway. }
  if Value in [csDie, csDieBack] then Collides := false;
end;

{ initialization / finalization ---------------------------------------------- }

procedure CreaturesKindsInit;
begin
  Werewolf := Resources.FindName('Werewolf') as TWerewolfKind;
  Ghost := Resources.FindName('Ghost') as TGhostKind;
  Spider := Resources.FindName('Spider') as TWalkAttackCreatureKind;
  SpiderQueen := Resources.FindName('SpiderQueen') as TWalkAttackCreatureKind;
  Arrow := Resources.FindName('Arrow') as TMissileCreatureKind;
end;

procedure DoInitialization;
begin
  RegisterResourceClass(TWerewolfKind, 'Werewolf');
  RegisterResourceClass(TGhostKind, 'Ghost');
end;

initialization
  DoInitialization;
end.

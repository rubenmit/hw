(*
 * Hedgewars, a free turn based strategy game
 * Copyright (c) 2004-2013 Andrey Korotaev <unC0Rr@gmail.com>
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; version 2 of the License
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307, USA
 *)

{$INCLUDE "options.inc"}

unit uGearsUtils;
interface
uses uTypes, uFloat;

procedure doMakeExplosion(X, Y, Radius: LongInt; AttackingHog: PHedgehog; Mask: Longword); inline;
procedure doMakeExplosion(X, Y, Radius: LongInt; AttackingHog: PHedgehog; Mask: Longword; const Tint: LongWord); 

function  ModifyDamage(dmg: Longword; Gear: PGear): Longword;
procedure ApplyDamage(Gear: PGear; AttackerHog: PHedgehog; Damage: Longword; Source: TDamageSource);
procedure spawnHealthTagForHH(HHGear: PGear; dmg: Longword);
procedure HHHurt(Hedgehog: PHedgehog; Source: TDamageSource);
procedure CheckHHDamage(Gear: PGear);
procedure CalcRotationDirAngle(Gear: PGear);
procedure ResurrectHedgehog(var gear: PGear);

procedure FindPlace(var Gear: PGear; withFall: boolean; Left, Right: LongInt); inline;
procedure FindPlace(var Gear: PGear; withFall: boolean; Left, Right: LongInt; skipProximity: boolean);

function  CheckGearNear(Gear: PGear; Kind: TGearType; rX, rY: LongInt): PGear;
function  CheckGearDrowning(var Gear: PGear): boolean;
procedure CheckCollision(Gear: PGear); inline;
procedure CheckCollisionWithLand(Gear: PGear); inline;

procedure AmmoShove(Ammo: PGear; Damage, Power: LongInt);
function  GearsNear(X, Y: hwFloat; Kind: TGearType; r: LongInt): PGearArrayS;
procedure SpawnBoxOfSmth;
procedure ShotgunShot(Gear: PGear);

procedure SetAllToActive;
procedure SetAllHHToActive; inline;
procedure SetAllHHToActive(Ice: boolean);

function  GetAmmo(Hedgehog: PHedgehog): TAmmoType;
function  GetUtility(Hedgehog: PHedgehog): TAmmoType;



function MakeHedgehogsStep(Gear: PGear) : boolean;

var doStepHandlers: array[TGearType] of TGearStepProcedure;


implementation
uses uSound, uCollisions, uUtils, uConsts, uVisualGears, uAIMisc,
    uVariables, uLandGraphics, uScript, uStats, uCaptions, uTeams, uStore,
    uLocale, uTextures, uRenderUtils, uRandom, SDLh, uDebug, 
    uGearsList, Math, uVisualGearsList, uGearsHandlersMess,
    uGearsHedgehog;

procedure doMakeExplosion(X, Y, Radius: LongInt; AttackingHog: PHedgehog; Mask: Longword); inline;
begin
    doMakeExplosion(X, Y, Radius, AttackingHog, Mask, $FFFFFFFF);
end;

procedure doMakeExplosion(X, Y, Radius: LongInt; AttackingHog: PHedgehog; Mask: Longword; const Tint: LongWord);
var Gear: PGear;
    dmg, dmgBase: LongInt;
    fX, fY, tdX, tdY: hwFloat;
    vg: PVisualGear;
    i, cnt: LongInt;
begin
if Radius > 4 then AddFileLog('Explosion: at (' + inttostr(x) + ',' + inttostr(y) + ')');
if Radius > 25 then KickFlakes(Radius, X, Y);

if ((Mask and EXPLNoGfx) = 0) then
    begin
    vg:= nil;
    if Radius > 50 then vg:= AddVisualGear(X, Y, vgtBigExplosion)
    else if Radius > 10 then vg:= AddVisualGear(X, Y, vgtExplosion);
    if vg <> nil then
        vg^.Tint:= Tint;
    end;
if (Mask and EXPLAutoSound) <> 0 then PlaySound(sndExplosion);

(*if (Mask and EXPLAllDamageInRadius) = 0 then
    dmgRadius:= Radius shl 1
else
    dmgRadius:= Radius;
dmgBase:= dmgRadius + cHHRadius div 2;*)
dmgBase:= Radius shl 1 + cHHRadius div 2;
fX:= int2hwFloat(X);
fY:= int2hwFloat(Y);
Gear:= GearsList;
while Gear <> nil do
    begin
    dmg:= 0;
    //dmg:= dmgRadius  + cHHRadius div 2 - hwRound(Distance(Gear^.X - int2hwFloat(X), Gear^.Y - int2hwFloat(Y)));
    //if (dmg > 1) and
    if (Gear^.State and gstNoDamage) = 0 then
        begin
        case Gear^.Kind of
            gtHedgehog,
                gtMine,
                gtBall,
                gtMelonPiece,
                gtGrenade,
                gtClusterBomb,
            //    gtCluster, too game breaking I think
                gtSMine,
                gtCase,
                gtTarget,
                gtFlame,
                gtKnife,
                gtExplosives: begin //,
                //gtStructure: begin
// Run the calcs only once we know we have a type that will need damage
                        tdX:= Gear^.X-fX;
                        tdY:= Gear^.Y-fY;
                        if LongInt(tdX.Round + tdY.Round + 2) < dmgBase then
                            dmg:= dmgBase - hwRound(Distance(tdX, tdY));
                        if dmg > 1 then
                            begin
                            dmg:= ModifyDamage(min(dmg div 2, Radius), Gear);
                            //AddFileLog('Damage: ' + inttostr(dmg));
                            if (Mask and EXPLNoDamage) = 0 then
                                begin
                                if not Gear^.Invulnerable then
                                    ApplyDamage(Gear, AttackingHog, dmg, dsExplosion)
                                else
                                    Gear^.State:= Gear^.State or gstWinner;
                                end;
                            if ((Mask and EXPLDoNotTouchAny) = 0) and (((Mask and EXPLDoNotTouchHH) = 0) or (Gear^.Kind <> gtHedgehog)) then
                                begin
                                DeleteCI(Gear);
                                Gear^.dX:= Gear^.dX + SignAs(_0_005 * dmg + cHHKick, tdX)/(Gear^.Density/_3);
                                Gear^.dY:= Gear^.dY + SignAs(_0_005 * dmg + cHHKick, tdY)/(Gear^.Density/_3);

                                Gear^.State:= (Gear^.State or gstMoving) and (not gstLoser);
                                if Gear^.Kind = gtKnife then Gear^.State:= Gear^.State and (not gstCollision);
                                if not Gear^.Invulnerable then
                                    Gear^.State:= (Gear^.State or gstMoving) and (not gstWinner);
                                Gear^.Active:= true;
                                if Gear^.Kind <> gtFlame then FollowGear:= Gear
                                end;
                            if ((Mask and EXPLPoisoned) <> 0) and (Gear^.Kind = gtHedgehog) and (not Gear^.Invulnerable) and ((Gear^.State and gstHHDeath) = 0) then
                                Gear^.Hedgehog^.Effects[hePoisoned] := 1;
                            end;

                        end;
                gtGrave: begin
// Run the calcs only once we know we have a type that will need damage
                        tdX:= Gear^.X-fX;
                        tdY:= Gear^.Y-fY;
                        if LongInt(tdX.Round + tdY.Round + 2) < dmgBase then
                            dmg:= dmgBase - hwRound(Distance(tdX, tdY));
                        if dmg > 1 then
                            begin
                            dmg:= ModifyDamage(min(dmg div 2, Radius), Gear);
                            Gear^.dY:= - _0_004 * dmg;
                            Gear^.Active:= true
                            end
                        end;
            end;
        end;
    Gear:= Gear^.NextGear
    end;

if (Mask and EXPLDontDraw) = 0 then
    if (GameFlags and gfSolidLand) = 0 then
        begin
        cnt:= DrawExplosion(X, Y, Radius) div 1608; // approx 2 16x16 circles to erase per chunk
        if (cnt > 0) and (SpritesData[sprChunk].Texture <> nil) then
            for i:= 0 to cnt do
                AddVisualGear(X, Y, vgtChunk)
        end;

uAIMisc.AwareOfExplosion(0, 0, 0)
end;

function ModifyDamage(dmg: Longword; Gear: PGear): Longword;
var i: hwFloat;
begin
(* Invulnerability cannot be placed in here due to still needing kicks
   Not without a new damage machine.
   King check should be in here instead of ApplyDamage since Tiy wants them kicked less
*)
i:= _1;
if (CurrentHedgehog <> nil) and CurrentHedgehog^.King then
    i:= _1_5;
if (Gear^.Hedgehog <> nil) and (Gear^.Hedgehog^.King or (Gear^.Hedgehog^.Effects[heFrozen] > 0)) then
    ModifyDamage:= hwRound(cDamageModifier * dmg * i * cDamagePercent * _0_5 * _0_01)
else
    ModifyDamage:= hwRound(cDamageModifier * dmg * i * cDamagePercent * _0_01)
end;

procedure ApplyDamage(Gear: PGear; AttackerHog: PHedgehog; Damage: Longword; Source: TDamageSource);
var s: shortstring;
    vampDmg, tmpDmg, i: Longword;
    vg: PVisualGear;
begin
    if Damage = 0 then
        exit; // nothing to apply

    if (Gear^.Kind = gtHedgehog) then
        begin
        Gear^.LastDamage := AttackerHog;

        Gear^.Hedgehog^.Team^.Clan^.Flawless:= false;
        HHHurt(Gear^.Hedgehog, Source);
        AddDamageTag(hwRound(Gear^.X), hwRound(Gear^.Y), Damage, Gear^.Hedgehog^.Team^.Clan^.Color);
        tmpDmg:= min(Damage, max(0,Gear^.Health-Gear^.Damage));
        if (Gear <> CurrentHedgehog^.Gear) and (CurrentHedgehog^.Gear <> nil) and (tmpDmg >= 1) then
            begin
            if cVampiric then
                begin
                vampDmg:= hwRound(int2hwFloat(tmpDmg)*_0_8);
                if vampDmg >= 1 then
                    begin
                    // was considering pulsing on attack, Tiy thinks it should be permanent while in play
                    //CurrentHedgehog^.Gear^.State:= CurrentHedgehog^.Gear^.State or gstVampiric;
                    inc(CurrentHedgehog^.Gear^.Health,vampDmg);
                    str(vampDmg, s);
                    s:= '+' + s;
                    AddCaption(s, CurrentHedgehog^.Team^.Clan^.Color, capgrpAmmoinfo);
                    RenderHealth(CurrentHedgehog^);
                    RecountTeamHealth(CurrentHedgehog^.Team);
                    i:= 0;
                    while i < vampDmg do
                        begin
                        vg:= AddVisualGear(hwRound(CurrentHedgehog^.Gear^.X), hwRound(CurrentHedgehog^.Gear^.Y), vgtStraightShot);
                        if vg <> nil then
                            with vg^ do
                                begin
                                Tint:= $FF0000FF;
                                State:= ord(sprHealth)
                                end;
                        inc(i, 5);
                        end;
                    end
                end;
        if ((GameFlags and gfKarma) <> 0) and 
        ((GameFlags and gfInvulnerable) = 0)
        and (not CurrentHedgehog^.Gear^.Invulnerable) then
            begin // this cannot just use Damage or it interrupts shotgun and gets you called stupid
            inc(CurrentHedgehog^.Gear^.Karma, tmpDmg);
            CurrentHedgehog^.Gear^.LastDamage := CurrentHedgehog;
            spawnHealthTagForHH(CurrentHedgehog^.Gear, tmpDmg);
            end;
        uStats.HedgehogDamaged(Gear, AttackerHog, Damage, false);    
        end;
    end else
    //else if Gear^.Kind <> gtStructure then // not gtHedgehog nor gtStructure
        Gear^.Hedgehog:= AttackerHog;
    inc(Gear^.Damage, Damage);
    
    ScriptCall('onGearDamage', Gear^.UID, Damage);
end;

procedure spawnHealthTagForHH(HHGear: PGear; dmg: Longword);
var tag: PVisualGear;
begin
tag:= AddVisualGear(hwRound(HHGear^.X), hwRound(HHGear^.Y), vgtHealthTag, dmg);
if (tag <> nil) then
    tag^.Hedgehog:= HHGear^.Hedgehog; // the tag needs the tag to determine the text color
AllInactive:= false;
HHGear^.Active:= true;
end;
    
procedure HHHurt(Hedgehog: PHedgehog; Source: TDamageSource);
begin
if Hedgehog^.Effects[heFrozen] <> 0 then exit;
if (Source = dsFall) or (Source = dsExplosion) then
    case random(3) of
        0: PlaySoundV(sndOoff1, Hedgehog^.Team^.voicepack);
        1: PlaySoundV(sndOoff2, Hedgehog^.Team^.voicepack);
        2: PlaySoundV(sndOoff3, Hedgehog^.Team^.voicepack);
    end
else if (Source = dsPoison) then
    case random(2) of
        0: PlaySoundV(sndPoisonCough, Hedgehog^.Team^.voicepack);
        1: PlaySoundV(sndPoisonMoan, Hedgehog^.Team^.voicepack);
    end
else
    case random(4) of
        0: PlaySoundV(sndOw1, Hedgehog^.Team^.voicepack);
        1: PlaySoundV(sndOw2, Hedgehog^.Team^.voicepack);
        2: PlaySoundV(sndOw3, Hedgehog^.Team^.voicepack);
        3: PlaySoundV(sndOw4, Hedgehog^.Team^.voicepack);
    end
end;

procedure CheckHHDamage(Gear: PGear);
var 
    dmg: Longword;
    i: LongWord;
    particle: PVisualGear;
begin
if _0_4 < Gear^.dY then
    begin
    dmg := ModifyDamage(1 + hwRound((Gear^.dY - _0_4) * 70), Gear);
    if Gear^.Hedgehog^.Effects[heFrozen] = 0 then
         PlaySound(sndBump)
    else PlaySound(sndFrozenHogImpact);
    if dmg < 1 then
        exit;

    for i:= min(12, (3 + dmg div 10)) downto 0 do
        begin
        particle := AddVisualGear(hwRound(Gear^.X) - 5 + Random(10), hwRound(Gear^.Y) + 12, vgtDust);
        if particle <> nil then
            particle^.dX := particle^.dX + (Gear^.dX.QWordValue / 21474836480);
        end;

    if (Gear^.Invulnerable) then
        exit;

    //if _0_6 < Gear^.dY then
    //    PlaySound(sndOw4, Gear^.Hedgehog^.Team^.voicepack)
    //else
    //    PlaySound(sndOw1, Gear^.Hedgehog^.Team^.voicepack);

    if Gear^.LastDamage <> nil then
        ApplyDamage(Gear, Gear^.LastDamage, dmg, dsFall)
    else
        ApplyDamage(Gear, CurrentHedgehog, dmg, dsFall);
    end
end;


procedure CalcRotationDirAngle(Gear: PGear);
var 
    dAngle: real;
begin
    // Frac/Round to be kind to JS as of 2012-08-27 where there is yet no int64/uint64
    //dAngle := (Gear^.dX.QWordValue + Gear^.dY.QWordValue) / $80000000;
    dAngle := (Gear^.dX.Round + Gear^.dY.Round) / 2 + (Gear^.dX.Frac/$100000000+Gear^.dY.Frac/$100000000);
    if not Gear^.dX.isNegative then
        Gear^.DirAngle := Gear^.DirAngle + dAngle
    else
        Gear^.DirAngle := Gear^.DirAngle - dAngle;

    if Gear^.DirAngle < 0 then
        Gear^.DirAngle := Gear^.DirAngle + 360
    else if 360 < Gear^.DirAngle then
        Gear^.DirAngle := Gear^.DirAngle - 360
end;

function CheckGearDrowning(var Gear: PGear): boolean;
var 
    skipSpeed, skipAngle, skipDecay: hwFloat;
    i, maxDrops, X, Y: LongInt;
    vdX, vdY: real;
    particle, splash: PVisualGear;
    isSubmersible: boolean;
begin
    // probably needs tweaking. might need to be in a case statement based upon gear type
    Y:= hwRound(Gear^.Y);
    if cWaterLine < Y + Gear^.Radius then
        begin
        if Gear^.State and gstInvisible <> 0 then
            begin
            if Gear^.Kind = gtGenericFaller then
                begin
                Gear^.X:= int2hwFloat(GetRandom(rightX-leftX)+leftX);
                Gear^.Y:= int2hwFloat(GetRandom(LAND_HEIGHT-topY)+topY);
                Gear^.dX:= _90-(GetRandomf*_360);
                Gear^.dY:= _90-(GetRandomf*_360)
                end
            else DeleteGear(Gear);
            exit
            end;
        isSubmersible:= ((Gear = CurrentHedgehog^.Gear) and (CurAmmoGear <> nil) and (CurAmmoGear^.State and gstSubmersible <> 0)) or (Gear^.State and gstSubmersible <> 0);
        skipSpeed := _0_25;
        skipAngle := _1_9;
        skipDecay := _0_87;
        X:= hwRound(Gear^.X);
        vdX:= hwFloat2Float(Gear^.dX);
        vdY:= hwFloat2Float(Gear^.dY);
        // this could perhaps be a tiny bit higher.
        if  (cWaterLine + 64 + Gear^.Radius > Y) and (hwSqr(Gear^.dX) + hwSqr(Gear^.dY) > skipSpeed) 
        and (hwAbs(Gear^.dX) > skipAngle * hwAbs(Gear^.dY)) then
            begin
            Gear^.dY.isNegative := true;
            Gear^.dY := Gear^.dY * skipDecay;
            Gear^.dX := Gear^.dX * skipDecay;
            CheckGearDrowning := false;
            PlaySound(sndSkip)
            end
        else
            begin
            if not isSubmersible then
                begin
                CheckGearDrowning := true;
                Gear^.State := gstDrowning;
                Gear^.RenderTimer := false;
                if (Gear^.Kind <> gtSniperRifleShot) and (Gear^.Kind <> gtShotgunShot)
                and (Gear^.Kind <> gtDEagleShot) and (Gear^.Kind <> gtSineGunShot) then
                    if Gear^.Kind = gtHedgehog then
                        begin
                        if Gear^.Hedgehog^.Effects[heResurrectable] <> 0 then
                            begin
                            // Gear could become nil after this, just exit to skip splashes
                            ResurrectHedgehog(Gear);
                            exit
                            end
                        else
                            begin
                            Gear^.doStep := @doStepDrowningGear;
                            Gear^.State := Gear^.State and (not gstHHDriven);
                            AddCaption(Format(GetEventString(eidDrowned), Gear^.Hedgehog^.Name), cWhiteColor, capgrpMessage);
                            end
                        end
                    else
                        Gear^.doStep := @doStepDrowningGear;
                        if Gear^.Kind = gtFlake then
                            exit // skip splashes 
                end
            else if (Y > cWaterLine + cVisibleWater*4) and 
                    ((Gear <> CurrentHedgehog^.Gear) or (CurAmmoGear = nil) or (CurAmmoGear^.State and gstSubmersible = 0)) then
                Gear^.doStep:= @doStepDrowningGear;
            if ((not isSubmersible) and (Y < cWaterLine + 64 + Gear^.Radius))
            or (isSubmersible and (Y < cWaterLine + 2 + Gear^.Radius) and (Gear = CurAmmoGear) and ((CurAmmoGear^.Pos = 0)
            and (CurAmmoGear^.dY < _0_01))) then
                if Gear^.Density * Gear^.dY > _1 then
                    PlaySound(sndSplash)
                else if Gear^.Density * Gear^.dY > _0_5 then 
                    PlaySound(sndSkip)
                else
                    PlaySound(sndDroplet2);
            end;

        if ((cReducedQuality and rqPlainSplash) = 0)
        and (((not isSubmersible) and (Y < cWaterLine + 64 + Gear^.Radius))
        or (isSubmersible and (Y < cWaterLine + 2 + Gear^.Radius) and (Gear = CurAmmoGear) and ((CurAmmoGear^.Pos = 0)
        and (CurAmmoGear^.dY < _0_01)))) then
            begin
            splash:= AddVisualGear(X, cWaterLine, vgtSplash);
            if splash <> nil then 
                with splash^ do
                begin
                Scale:= hwFloat2Float(Gear^.Density / _3 * Gear^.dY);
                if Scale > 1 then Scale:= power(Scale,0.3333)
                else Scale:= Scale + ((1-Scale) / 2);
                if Scale > 1 then Timer:= round(min(Scale*0.0005/cGravityf,4))
                else Timer:= 1;
                // Low Gravity
                FrameTicks:= FrameTicks*Timer;
                end;

            maxDrops := (hwRound(Gear^.Density) * 3) div 2 + round(vdX * hwRound(Gear^.Density) * 6) + round(vdY * hwRound(Gear^.Density) * 6);
            for i:= max(maxDrops div 3, min(32, Random(maxDrops))) downto 0 do
                begin
                particle := AddVisualGear(X - 3 + Random(7), cWaterLine, vgtDroplet);
                if particle <> nil then
                    with particle^ do
                        begin
                        dX := dX - vdX / 10;
                        dY := dY - vdY / 5;
                        if splash <> nil then
                            begin
                            if splash^.Scale > 1 then 
                                begin
                                dX:= dX * power(splash^.Scale,0.3333); // tone down the droplet height further
                                dY:= dY * power(splash^.Scale, 0.3333)
                                end
                            else 
                                begin
                                dX:= dX * splash^.Scale;
                                dY:= dY * splash^.Scale
                                end
                            end
                        end
                end
            end;
        if isSubmersible and (Gear = CurAmmoGear) and (CurAmmoGear^.Pos = 0) then
            CurAmmoGear^.Pos := 1000
        end
    else
        CheckGearDrowning := false;
end;


procedure ResurrectHedgehog(var gear: PGear);
var tempTeam : PTeam;
    sparkles: PVisualGear;
    gX, gY: LongInt;
begin
    if (Gear^.LastDamage <> nil) then
        uStats.HedgehogDamaged(Gear, Gear^.LastDamage, 0, true)
    else
        uStats.HedgehogDamaged(Gear, CurrentHedgehog, 0, true);
    AttackBar:= 0;
    gear^.dX := _0;
    gear^.dY := _0;
    gear^.Damage := 0;
    gear^.Health := gear^.Hedgehog^.InitialHealth;
    gear^.Hedgehog^.Effects[hePoisoned] := 0;
    if (CurrentHedgehog^.Effects[heResurrectable] = 0) or ((CurrentHedgehog^.Effects[heResurrectable] <> 0)
          and (Gear^.Hedgehog^.Team^.Clan <> CurrentHedgehog^.Team^.Clan)) then
        with CurrentHedgehog^ do 
            begin
            inc(Team^.stats.AIKills);
            FreeTexture(Team^.AIKillsTex);
            Team^.AIKillsTex := RenderStringTex(inttostr(Team^.stats.AIKills), Team^.Clan^.Color, fnt16);
            end;
    tempTeam := gear^.Hedgehog^.Team;
    DeleteCI(gear);
    gX := hwRound(gear^.X);
    gY := hwRound(gear^.Y);
    // might need more sparkles for a column
    sparkles:= AddVisualGear(gX, gY, vgtDust, 1);
    if sparkles <> nil then
        begin
        sparkles^.Tint:= tempTeam^.Clan^.Color shl 8 or $FF;
        //sparkles^.Angle:= random(360);
        end;
    FindPlace(gear, false, 0, LAND_WIDTH, true); 
    if gear <> nil then
        begin
        AddVisualGear(hwRound(gear^.X), hwRound(gear^.Y), vgtExplosion);
        PlaySound(sndWarp);
        RenderHealth(gear^.Hedgehog^);
        ScriptCall('onGearResurrect', gear^.uid);
        gear^.State := gstWait;
        end;
    RecountTeamHealth(tempTeam);
end;

function CountNonZeroz(x, y, r, c: LongInt; mask: LongWord): LongInt;
var i: LongInt;
    count: LongInt = 0;
begin
    if (y and LAND_HEIGHT_MASK) = 0 then
        for i:= max(x - r, 0) to min(x + r, LAND_WIDTH - 4) do
            if Land[y, i] and mask <> 0 then
            begin
                inc(count);
                if count = c then
                begin
                    CountNonZeroz:= count;
                    exit
                end;
            end;
    CountNonZeroz:= count;
end;


function NoGearsToAvoid(mX, mY: LongInt; rX, rY: LongInt): boolean;
var t: PGear;
begin
NoGearsToAvoid:= false;
t:= GearsList;
rX:= sqr(rX);
rY:= sqr(rY);
while t <> nil do
    begin
    if t^.Kind <= gtExplosives then
        if not (hwSqr(int2hwFloat(mX) - t^.X) / rX + hwSqr(int2hwFloat(mY) - t^.Y) / rY > _1) then
            exit;
    t:= t^.NextGear
    end;
NoGearsToAvoid:= true
end;

procedure FindPlace(var Gear: PGear; withFall: boolean; Left, Right: LongInt); inline;
begin
    FindPlace(Gear, withFall, Left, Right, false);
end;

procedure FindPlace(var Gear: PGear; withFall: boolean; Left, Right: LongInt; skipProximity: boolean);
var x: LongInt;
    y, sy: LongInt;
    ar: array[0..1023] of TPoint;
    ar2: array[0..2047] of TPoint;
    cnt, cnt2: Longword;
    delta: LongInt;
    ignoreNearObjects, ignoreOverlap, tryAgain: boolean;
begin
ignoreNearObjects:= false; // try not skipping proximity at first
ignoreOverlap:= false; // this not only skips proximity, but allows overlapping objects (barrels, mines, hogs, crates).  Saving it for a 3rd pass.  With this active, winning AI Survival goes back to virtual impossibility
tryAgain:= true;
while tryAgain do
    begin
    delta:= LAND_WIDTH div 16;
    cnt2:= 0;
    repeat
        x:= Left + max(LAND_WIDTH div 2048, LongInt(GetRandom(Delta)));
        repeat
            inc(x, Delta);
            cnt:= 0;
            y:= min(1024, topY) - 2 * Gear^.Radius;
            while y < cWaterLine do
                begin
                repeat
                    inc(y, 2);
                until (y >= cWaterLine) or
                        (not ignoreOverlap and (CountNonZeroz(x, y, Gear^.Radius - 1, 1, $FFFF) = 0)) or 
                        (ignoreOverlap and (CountNonZeroz(x, y, Gear^.Radius - 1, 1, lfLandMask) = 0));

                sy:= y;

                repeat
                    inc(y);
                until (y >= cWaterLine) or
                        (not ignoreOverlap and (CountNonZeroz(x, y, Gear^.Radius - 1, 1, $FFFF) <> 0)) or 
                        (ignoreOverlap and (CountNonZeroz(x, y, Gear^.Radius - 1, 1, lfLandMask) <> 0)); 

                if (y - sy > Gear^.Radius * 2)
                    and (((Gear^.Kind = gtExplosives)
                    and (y < cWaterLine)
                    and (ignoreNearObjects or NoGearsToAvoid(x, y - Gear^.Radius, 60, 60))
                    and (CountNonZeroz(x, y+1, Gear^.Radius - 1, Gear^.Radius+1, $FFFF) > Gear^.Radius))
                or
                    ((Gear^.Kind <> gtExplosives)
                    and (y < cWaterLine)
                    and (ignoreNearObjects or NoGearsToAvoid(x, y - Gear^.Radius, 110, 110))
                    )) then
                    begin
                    ar[cnt].X:= x;
                    if withFall then
                        ar[cnt].Y:= sy + Gear^.Radius
                    else
                        ar[cnt].Y:= y - Gear^.Radius;
                    inc(cnt)
                    end;

                inc(y, 10)
                end;

            if cnt > 0 then
                with ar[GetRandom(cnt)] do
                    begin
                    ar2[cnt2].x:= x;
                    ar2[cnt2].y:= y;
                    inc(cnt2)
                    end
        until (x + Delta > Right);

        dec(Delta, 60)
    until (cnt2 > 0) or (Delta < 70);
    // if either of these has not been tried, do another pass
    if (cnt2 = 0) and skipProximity and (not ignoreOverlap) then
        tryAgain:= true
    else tryAgain:= false;
    if ignoreNearObjects then ignoreOverlap:= true;
    ignoreNearObjects:= true;
    end;

if cnt2 > 0 then
    with ar2[GetRandom(cnt2)] do
        begin
        Gear^.X:= int2hwFloat(x);
        Gear^.Y:= int2hwFloat(y);
        AddFileLog('Assigned Gear coordinates (' + inttostr(x) + ',' + inttostr(y) + ')');
        end
    else
    begin
    OutError('Can''t find place for Gear', false);
    if Gear^.Kind = gtHedgehog then
        Gear^.Hedgehog^.Effects[heResurrectable] := 0;
    DeleteGear(Gear);
    Gear:= nil
    end
end;

function CheckGearNear(Gear: PGear; Kind: TGearType; rX, rY: LongInt): PGear;
var t: PGear;
begin
t:= GearsList;
rX:= sqr(rX);
rY:= sqr(rY);

while t <> nil do
    begin
    if (t <> Gear) and (t^.Kind = Kind) then
        if not((hwSqr(Gear^.X - t^.X) / rX + hwSqr(Gear^.Y - t^.Y) / rY) > _1) then
        begin
            CheckGearNear:= t;
            exit;
        end;
    t:= t^.NextGear
    end;

CheckGearNear:= nil
end;

procedure CheckCollision(Gear: PGear); inline;
begin
    if TestCollisionXwithGear(Gear, hwSign(Gear^.dX))
    or (TestCollisionYwithGear(Gear, hwSign(Gear^.dY)) <> 0) then
        Gear^.State := Gear^.State or gstCollision
    else
        Gear^.State := Gear^.State and (not gstCollision)
end;

procedure CheckCollisionWithLand(Gear: PGear); inline;
begin
    if TestCollisionX(Gear, hwSign(Gear^.dX))
    or TestCollisionY(Gear, hwSign(Gear^.dY)) then
        Gear^.State := Gear^.State or gstCollision
    else 
        Gear^.State := Gear^.State and (not gstCollision)
end;

function MakeHedgehogsStep(Gear: PGear) : boolean;
begin
    if TestCollisionXwithGear(Gear, hwSign(Gear^.dX)) then if (TestCollisionYwithGear(Gear, -1) = 0) then
        begin
        Gear^.Y:= Gear^.Y - _1;
    if TestCollisionXwithGear(Gear, hwSign(Gear^.dX)) then if (TestCollisionYwithGear(Gear, -1) = 0) then
        begin
        Gear^.Y:= Gear^.Y - _1;
    if TestCollisionXwithGear(Gear, hwSign(Gear^.dX)) then if (TestCollisionYwithGear(Gear, -1) = 0) then
        begin
        Gear^.Y:= Gear^.Y - _1;
    if TestCollisionXwithGear(Gear, hwSign(Gear^.dX)) then if (TestCollisionYwithGear(Gear, -1) = 0) then
        begin
        Gear^.Y:= Gear^.Y - _1;
    if TestCollisionXwithGear(Gear, hwSign(Gear^.dX)) then if (TestCollisionYwithGear(Gear, -1) = 0) then
        begin
        Gear^.Y:= Gear^.Y - _1;
    if TestCollisionXwithGear(Gear, hwSign(Gear^.dX)) then if (TestCollisionYwithGear(Gear, -1) = 0) then
        begin
        Gear^.Y:= Gear^.Y - _1;
        if TestCollisionXwithGear(Gear, hwSign(Gear^.dX)) then
            Gear^.Y:= Gear^.Y + _6
        end else Gear^.Y:= Gear^.Y + _5 else
        end else Gear^.Y:= Gear^.Y + _4 else
        end else Gear^.Y:= Gear^.Y + _3 else
        end else Gear^.Y:= Gear^.Y + _2 else
        end else Gear^.Y:= Gear^.Y + _1
        end;

    if not TestCollisionXwithGear(Gear, hwSign(Gear^.dX)) then
        begin
        Gear^.X:= Gear^.X + SignAs(_1, Gear^.dX);
        MakeHedgehogsStep:= true
        end else
        MakeHedgehogsStep:= false;

    if TestCollisionYwithGear(Gear, 1) = 0 then
        begin
        Gear^.Y:= Gear^.Y + _1;
    if TestCollisionYwithGear(Gear, 1) = 0 then
        begin
        Gear^.Y:= Gear^.Y + _1;
    if TestCollisionYwithGear(Gear, 1) = 0 then
        begin
        Gear^.Y:= Gear^.Y + _1;
    if TestCollisionYwithGear(Gear, 1) = 0 then
        begin
        Gear^.Y:= Gear^.Y + _1;
    if TestCollisionYwithGear(Gear, 1) = 0 then
        begin
        Gear^.Y:= Gear^.Y + _1;
    if TestCollisionYwithGear(Gear, 1) = 0 then
        begin
        Gear^.Y:= Gear^.Y + _1;
    if TestCollisionYwithGear(Gear, 1) = 0 then
        begin
        Gear^.Y:= Gear^.Y - _6;
        Gear^.dY:= _0;
        Gear^.State:= Gear^.State or gstMoving;
        exit
        end;
        end
        end
        end
        end
        end
        end;
end;


procedure ShotgunShot(Gear: PGear);
var t: PGear;
    dmg, r, dist: LongInt;
    dx, dy: hwFloat;
begin
Gear^.Radius:= cShotgunRadius;
t:= GearsList;
while t <> nil do
    begin
    case t^.Kind of
        gtHedgehog,
            gtMine,
            gtSMine,
            gtKnife,
            gtCase,
            gtTarget,
            gtExplosives: begin//,
//            gtStructure: begin
//addFileLog('ShotgunShot radius: ' + inttostr(Gear^.Radius) + ', t^.Radius = ' + inttostr(t^.Radius) + ', distance = ' + inttostr(dist) + ', dmg = ' + inttostr(dmg));
                    dmg:= 0;
                    r:= Gear^.Radius + t^.Radius;
                    dx:= Gear^.X-t^.X;
                    dx.isNegative:= false;
                    dy:= Gear^.Y-t^.Y;
                    dy.isNegative:= false;
                    if r-hwRound(dx+dy) > 0 then
                        begin
                        dist:= hwRound(Distance(dx, dy));
                        dmg:= ModifyDamage(min(r - dist, 25), t);
                        end;
                    if dmg > 0 then
                        begin
                        if (not t^.Invulnerable) then
                            ApplyDamage(t, Gear^.Hedgehog, dmg, dsBullet)
                        else
                            Gear^.State:= Gear^.State or gstWinner;

                        DeleteCI(t);
                        t^.dX:= t^.dX + Gear^.dX * dmg * _0_01 + SignAs(cHHKick, Gear^.dX);
                        t^.dY:= t^.dY + Gear^.dY * dmg * _0_01;
                        t^.State:= t^.State or gstMoving;
                        if t^.Kind = gtKnife then t^.State:= t^.State and (not gstCollision);
                        t^.Active:= true;
                        FollowGear:= t
                        end
                    end;
            gtGrave: begin
                    dmg:= 0;
                    r:= Gear^.Radius + t^.Radius;
                    dx:= Gear^.X-t^.X;
                    dx.isNegative:= false;
                    dy:= Gear^.Y-t^.Y;
                    dy.isNegative:= false;
                    if r-hwRound(dx+dy) > 0 then
                        begin
                        dist:= hwRound(Distance(dx, dy));
                        dmg:= ModifyDamage(min(r - dist, 25), t);
                        end;
                    if dmg > 0 then
                        begin
                        t^.dY:= - _0_1;
                        t^.Active:= true
                        end
                    end;
        end;
    t:= t^.NextGear
    end;
if (GameFlags and gfSolidLand) = 0 then
    DrawExplosion(hwRound(Gear^.X), hwRound(Gear^.Y), cShotgunRadius)
end;

procedure AmmoShove(Ammo: PGear; Damage, Power: LongInt);
var t: PGearArray;
    Gear: PGear;
    i, j, tmpDmg: LongInt;
    VGear: PVisualGear;
begin
t:= CheckGearsCollision(Ammo);
// Just to avoid hogs on rope dodging fire.
if (CurAmmoGear <> nil) and ((CurAmmoGear^.Kind = gtRope) or (CurAmmoGear^.Kind = gtJetpack) or (CurAmmoGear^.Kind = gtBirdy))
and (CurrentHedgehog^.Gear <> nil) and (CurrentHedgehog^.Gear^.CollisionIndex = -1)
and (sqr(hwRound(Ammo^.X) - hwRound(CurrentHedgehog^.Gear^.X)) + sqr(hwRound(Ammo^.Y) - hwRound(CurrentHedgehog^.Gear^.Y)) <= sqr(cHHRadius + Ammo^.Radius)) then
    begin
    t^.ar[t^.Count]:= CurrentHedgehog^.Gear;
    inc(t^.Count)
    end;

i:= t^.Count;

if (Ammo^.Kind = gtFlame) and (i > 0) then
    Ammo^.Health:= 0;
while i > 0 do
    begin
    dec(i);
    Gear:= t^.ar[i];
    if ((Ammo^.Kind = gtFlame) or (Ammo^.Kind = gtBlowTorch)) and 
       (Gear^.Kind = gtHedgehog) and (Gear^.Hedgehog^.Effects[heFrozen] > 255) then
        Gear^.Hedgehog^.Effects[heFrozen]:= max(255,Gear^.Hedgehog^.Effects[heFrozen]-10000);
    tmpDmg:= ModifyDamage(Damage, Gear);
    if (Gear^.State and gstNoDamage) = 0 then
        begin

        if (Ammo^.Kind = gtDEagleShot) or (Ammo^.Kind = gtSniperRifleShot) then 
            begin
            VGear := AddVisualGear(hwround(Ammo^.X), hwround(Ammo^.Y), vgtBulletHit);
            if VGear <> nil then
                VGear^.Angle := DxDy2Angle(-Ammo^.dX, Ammo^.dY);
            end;

        if (Gear^.Kind = gtHedgehog) and (Ammo^.State and gsttmpFlag <> 0) and (Ammo^.Kind = gtShover) then
            Gear^.FlightTime:= 1;


        case Gear^.Kind of
            gtHedgehog,
            gtMine,
            gtSMine,
            gtKnife,
            gtTarget,
            gtCase,
            gtExplosives: //,
            //gtStructure:
            begin
            if (Ammo^.Kind = gtDrill) then
                begin
                Ammo^.Timer:= 0;
                exit;
                end;
            if (not Gear^.Invulnerable) then
                begin
                if (Ammo^.Kind = gtKnife) and (tmpDmg > 0) then
                    for j:= 1 to max(1,min(3,tmpDmg div 5)) do
                        begin
                        VGear:= AddVisualGear(hwRound(Ammo^.X-((Ammo^.X-Gear^.X)/_2)), hwRound(Ammo^.Y-((Ammo^.Y-Gear^.Y)/_2)), vgtStraightShot);
                        if VGear <> nil then
                            with VGear^ do
                                begin
                                Tint:= $FFCC00FF;
                                Angle:= random(360);
                                dx:= 0.0005 * (random(100));
                                dy:= 0.0005 * (random(100));
                                if random(2) = 0 then
                                    dx := -dx;
                                if random(2) = 0 then
                                    dy := -dy;
                                FrameTicks:= 600+random(200);
                                State:= ord(sprStar)
                                end
                        end;
                ApplyDamage(Gear, Ammo^.Hedgehog, tmpDmg, dsShove)
                end
            else
                Gear^.State:= Gear^.State or gstWinner;
            if (Gear^.Kind = gtExplosives) and (Ammo^.Kind = gtBlowtorch) then 
                begin
                if (Ammo^.Hedgehog^.Gear <> nil) then
                    Ammo^.Hedgehog^.Gear^.State:= Ammo^.Hedgehog^.Gear^.State and (not gstNotKickable);
                ApplyDamage(Gear, Ammo^.Hedgehog, tmpDmg * 100, dsUnknown); // crank up damage for explosives + blowtorch
                end;

            if (Gear^.Kind = gtHedgehog) and (Gear^.Hedgehog^.King or (Gear^.Hedgehog^.Effects[heFrozen] > 0)) then
                begin
                Gear^.dX:= Ammo^.dX * Power * _0_005;
                Gear^.dY:= Ammo^.dY * Power * _0_005
                end
            else if ((Ammo^.Kind <> gtFlame) or (Gear^.Kind = gtHedgehog)) and (Power <> 0) then
                begin
                Gear^.dX:= Ammo^.dX * Power * _0_01;
                Gear^.dY:= Ammo^.dY * Power * _0_01
                end;

            if (not isZero(Gear^.dX)) or (not isZero(Gear^.dY)) then
                begin
                Gear^.Active:= true;
                DeleteCI(Gear);
                Gear^.State:= Gear^.State or gstMoving;
                if Gear^.Kind = gtKnife then Gear^.State:= Gear^.State and (not gstCollision);
                // move the gear upwards a bit to throw it over tiny obstacles at start
                if TestCollisionXwithGear(Gear, hwSign(Gear^.dX)) then
                    begin
                    if not (TestCollisionXwithXYShift(Gear, _0, -3, hwSign(Gear^.dX))
                    or (TestCollisionYwithGear(Gear, -1) <> 0)) then
                        Gear^.Y:= Gear^.Y - _1;
                    if not (TestCollisionXwithXYShift(Gear, _0, -2, hwSign(Gear^.dX))
                    or (TestCollisionYwithGear(Gear, -1) <> 0)) then
                        Gear^.Y:= Gear^.Y - _1;
                    if not (TestCollisionXwithXYShift(Gear, _0, -1, hwSign(Gear^.dX))
                    or (TestCollisionYwithGear(Gear, -1) <> 0)) then
                        Gear^.Y:= Gear^.Y - _1;
                    end
                end;


            if (Ammo^.Kind <> gtFlame) or ((Ammo^.State and gsttmpFlag) = 0) then
                FollowGear:= Gear
            end;
        end
        end;
    end;
if i <> 0 then
    SetAllToActive
end;


function CountGears(Kind: TGearType): Longword;
var t: PGear;
    count: Longword = 0;
begin

t:= GearsList;
while t <> nil do
    begin
    if t^.Kind = Kind then
        inc(count);
    t:= t^.NextGear
    end;
CountGears:= count;
end;

procedure SetAllToActive;
var t: PGear;
begin
AllInactive:= false;
t:= GearsList;
while t <> nil do
    begin
    t^.Active:= true;
    t:= t^.NextGear
    end
end;

procedure SetAllHHToActive; inline;
begin
SetAllHHToActive(true)
end;


procedure SetAllHHToActive(Ice: boolean);
var t: PGear;
begin
AllInactive:= false;
t:= GearsList;
while t <> nil do
    begin
    if (t^.Kind = gtHedgehog) or (t^.Kind = gtExplosives) then
        begin
        if (t^.Kind = gtHedgehog) and Ice then CheckIce(t);
        t^.Active:= true
        end;
    t:= t^.NextGear
    end
end;


var GearsNearArray : TPGearArray;
function GearsNear(X, Y: hwFloat; Kind: TGearType; r: LongInt): PGearArrayS;
var
    t: PGear;
    s: Longword;
begin
    r:= r*r;
    s:= 0;
    SetLength(GearsNearArray, s);
    t := GearsList;
    while t <> nil do 
        begin
        if (t^.Kind = Kind) 
            and ((X - t^.X)*(X - t^.X) + (Y - t^.Y)*(Y-t^.Y) < int2hwFloat(r)) then
            begin
            inc(s);
            SetLength(GearsNearArray, s);
            GearsNearArray[s - 1] := t;
            end;
        t := t^.NextGear;
    end;

    GearsNear.size:= s;
    GearsNear.ar:= @GearsNearArray
end;


procedure SpawnBoxOfSmth;
var t, aTot, uTot, a, h: LongInt;
    i: TAmmoType;
begin
if (PlacingHogs) or
    (cCaseFactor = 0)
    or (CountGears(gtCase) >= 5)
    or (GetRandom(cCaseFactor) <> 0) then
       exit;

FollowGear:= nil;
aTot:= 0;
uTot:= 0;
for i:= Low(TAmmoType) to High(TAmmoType) do
    if (Ammoz[i].Ammo.Propz and ammoprop_Utility) = 0 then
        inc(aTot, Ammoz[i].Probability)
    else
        inc(uTot, Ammoz[i].Probability);

t:=0;
a:=aTot;
h:= 1;

if (aTot+uTot) <> 0 then
    if ((GameFlags and gfInvulnerable) = 0) then
        begin
        h:= cHealthCaseProb * 100;
        t:= GetRandom(10000);
        a:= (10000-h)*aTot div (aTot+uTot)
        end
    else
        begin
        t:= GetRandom(aTot+uTot);
        h:= 0
        end;


if t<h then
    begin
    FollowGear:= AddGear(0, 0, gtCase, 0, _0, _0, 0);
    FollowGear^.Health:= cHealthCaseAmount;
    FollowGear^.Pos:= posCaseHealth;
    AddCaption(GetEventString(eidNewHealthPack), cWhiteColor, capgrpAmmoInfo);
    end
else if (t<a+h) then
    begin
    t:= aTot;
    if (t > 0) then
        begin
        FollowGear:= AddGear(0, 0, gtCase, 0, _0, _0, 0);
        t:= GetRandom(t);
        i:= Low(TAmmoType);
        FollowGear^.Pos:= posCaseAmmo;
        FollowGear^.AmmoType:= i;
        AddCaption(GetEventString(eidNewAmmoPack), cWhiteColor, capgrpAmmoInfo);
        end
    end
else
    begin
    t:= uTot;
    if (t > 0) then
        begin
        FollowGear:= AddGear(0, 0, gtCase, 0, _0, _0, 0);
        t:= GetRandom(t);
        i:= Low(TAmmoType);
        FollowGear^.Pos:= posCaseUtility;
        FollowGear^.AmmoType:= i;
        AddCaption(GetEventString(eidNewUtilityPack), cWhiteColor, capgrpAmmoInfo);
        end
    end;

// handles case of no ammo or utility crates - considered also placing booleans in uAmmos and altering probabilities
if (FollowGear <> nil) then
    begin
    FindPlace(FollowGear, true, 0, LAND_WIDTH);

    if (FollowGear <> nil) then
        AddVoice(sndReinforce, CurrentTeam^.voicepack)
    end
end;


function GetAmmo(Hedgehog: PHedgehog): TAmmoType;
var t, aTot: LongInt;
    i: TAmmoType;
begin
Hedgehog:= Hedgehog; // avoid hint

aTot:= 0;
for i:= Low(TAmmoType) to High(TAmmoType) do
    if (Ammoz[i].Ammo.Propz and ammoprop_Utility) = 0 then
        inc(aTot, Ammoz[i].Probability);

t:= aTot;
i:= Low(TAmmoType);
if (t > 0) then
    begin
    t:= GetRandom(t);
    while t >= 0 do
        begin
        inc(i);
        if (Ammoz[i].Ammo.Propz and ammoprop_Utility) = 0 then
            dec(t, Ammoz[i].Probability)
        end
    end;
GetAmmo:= i
end;

function GetUtility(Hedgehog: PHedgehog): TAmmoType;
var t, uTot: LongInt;
    i: TAmmoType;
begin

uTot:= 0;
for i:= Low(TAmmoType) to High(TAmmoType) do
    if ((Ammoz[i].Ammo.Propz and ammoprop_Utility) <> 0)
    and ((Hedgehog^.Team^.HedgehogsNumber > 1) or (Ammoz[i].Ammo.AmmoType <> amSwitch)) then
        inc(uTot, Ammoz[i].Probability);

t:= uTot;
i:= Low(TAmmoType);
if (t > 0) then
    begin
    t:= GetRandom(t);
    while t >= 0 do
        begin
        inc(i);
        if ((Ammoz[i].Ammo.Propz and ammoprop_Utility) <> 0) and ((Hedgehog^.Team^.HedgehogsNumber > 1)
        or (Ammoz[i].Ammo.AmmoType <> amSwitch)) then
            dec(t, Ammoz[i].Probability)
        end
    end;
GetUtility:= i
end;


end.

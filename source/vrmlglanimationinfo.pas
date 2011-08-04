{
  Copyright 2006-2011 Michalis Kamburelis.

  This file is part of "Kambi VRML game engine".

  "Kambi VRML game engine" is free software; you can redistribute it and/or modify
  it under the terms of the GNU General Public License as published by
  the Free Software Foundation; either version 2 of the License, or
  (at your option) any later version.

  "Kambi VRML game engine" is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
  GNU General Public License for more details.

  You should have received a copy of the GNU General Public License
  along with "Kambi VRML game engine"; if not, write to the Free Software
  Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA

  ----------------------------------------------------------------------------
}

{ }
unit VRMLGLAnimationInfo;

interface

uses Classes, VRMLGLAnimation, VRMLGLRenderer, KambiUtils, DOM;

type
  { Simple class to postpone loading vrml files that will be used
    for TVRMLGLAnimation, and actually creating TVRMLGLAnimation instances.
    Why ? Because loading all these files can be quite time-consuming. }
  TVRMLGLAnimationInfo = class
  private
    FModelFileNames: TKamStringList;
    FTimes: TDynSingleArray;
    FScenesPerTime: Cardinal;
    FTimeLoop, FTimeBackwards: boolean;
    FCache: TVRMLGLRendererContextCache;
    FEqualityEpsilon: Single;
  public
    constructor Create(
      const AModelFileNames: array of string;
      const ATimes: array of Single;
      AScenesPerTime: Cardinal;
      const AEqualityEpsilon: Single;
      ATimeLoop, ATimeBackwards: boolean;
      ACache: TVRMLGLRendererContextCache);

    { Constructor that loads animation settings from a *.kanim file.
      File format is described in ../../doc/kanim_format.txt file. }
    constructor CreateFromFile(const FileName: string;
      ACache: TVRMLGLRendererContextCache);

    { Constructor that loads animation settings from DOM node representing
      *.kanim file.
      File format is described in ../../doc/kanim_format.txt file.
      @seealso TVRMLGLAnimation.LoadFromDOMElement. }
    constructor CreateFromDOMElement(Element: TDOMElement;
      const BasePath: string;
      ACache: TVRMLGLRendererContextCache = nil);

    destructor Destroy; override;

    { These properties are just initialized in our constructor
      and then used when calling CreateAnimation.
      You can freely change them after creation.

      In particular, this way you can change whatever setting was read
      from *.kanim file if you used CreateFromFile.

      @groupBegin }
    property ModelFileNames: TKamStringList read FModelFileNames;
    property Times: TDynSingleArray read FTimes;

    property ScenesPerTime: Cardinal read FScenesPerTime write FScenesPerTime;
    property EqualityEpsilon: Single read FEqualityEpsilon write FEqualityEpsilon;
    property TimeLoop: boolean read FTimeLoop write FTimeLoop;
    property TimeBackwards: boolean read FTimeBackwards write FTimeBackwards;
    property Cache: TVRMLGLRendererContextCache
      read FCache write FCache;
    { @groupEnd }

    { Remember that you're responsible for returned TVRMLGLAnimation
      instance after calling this function.

      @param(FirstRootNodesPool
        If non-nil, this can be used to slightly reduce animation loading
        time and memory use:

        We check whether we have AModelFileNames[0] among FirstRootNodesPool.
        If yes, then we will reuse this FirstRootNodesPool.Objects[]
        (and create animation with OwnsFirstRootNode = false).

        This allows you to prepare some commonly used root nodes and put
        them in FirstRootNodesPool before calling
        TVRMLGLAnimationInfo.CreateAnimation. This way loading time
        will be faster, and also display lists sharing may be greater,
        as the same RootNode may be shared by a couple of TVRMLGLAnimation
        instances.

        Be sure to remove these nodes (free them and remove them from
        FirstRootNodesPool) after you're sure that all animations that
        used them were destroyed.) }
    function CreateAnimation(FirstRootNodesPool: TStringList): TVRMLGLAnimation;
  end;

implementation

uses SysUtils, VRMLNodes, X3DLoad;

constructor TVRMLGLAnimationInfo.Create(
  const AModelFileNames: array of string;
  const ATimes: array of Single;
  AScenesPerTime: Cardinal;
  const AEqualityEpsilon: Single;
  ATimeLoop, ATimeBackwards: boolean;
  ACache: TVRMLGLRendererContextCache);
begin
  inherited Create;

  FModelFileNames := TKamStringList.Create;
  FTimes := TDynSingleArray.Create;

  FModelFileNames.AddArray(AModelFileNames);
  FTimes.AddArray(ATimes);

  FScenesPerTime := AScenesPerTime;
  FEqualityEpsilon := AEqualityEpsilon;
  FTimeLoop := ATimeLoop;
  FTimeBackwards := ATimeBackwards;

  FCache := ACache;
end;

constructor TVRMLGLAnimationInfo.CreateFromFile(const FileName: string;
  ACache: TVRMLGLRendererContextCache);
begin
  inherited Create;

  FModelFileNames := TKamStringList.Create;
  FTimes := TDynSingleArray.Create;

  TVRMLGLAnimation.LoadFromFileToVars(FileName,
    FModelFileNames, FTimes, FScenesPerTime,
    FEqualityEpsilon, FTimeLoop, FTimeBackwards);

  FCache := ACache;
end;

constructor TVRMLGLAnimationInfo.CreateFromDOMElement(Element: TDOMElement;
  const BasePath: string;
  ACache: TVRMLGLRendererContextCache);
begin
  inherited Create;

  FModelFileNames := TKamStringList.Create;
  FTimes := TDynSingleArray.Create;

  TVRMLGLAnimation.LoadFromDOMElementToVars(Element, BasePath,
    FModelFileNames, FTimes, FScenesPerTime,
    FEqualityEpsilon, FTimeLoop, FTimeBackwards);

  FCache := ACache;
end;

destructor TVRMLGLAnimationInfo.Destroy;
begin
  FreeAndNil(FModelFileNames);
  FreeAndNil(FTimes);
  inherited;
end;

function TVRMLGLAnimationInfo.CreateAnimation(
  FirstRootNodesPool: TStringList): TVRMLGLAnimation;
var
  RootNodes: TVRMLNodeList;
  I: Integer;
  FirstRootNodeIndex: Integer;
  OwnsFirstRootNode: boolean;
begin
  RootNodes := TVRMLNodeList.Create(false);
  try
    RootNodes.Count := FModelFileNames.Count;

    { $define DEBUG_ANIMATION_LOADING}

    {$ifdef DEBUG_ANIMATION_LOADING}
    Writeln('Loading animation:');
    for I := 0 to RootNodes.High do
      Writeln('  RootNodes[I] from "', FModelFileNames[I], '"');
    {$endif}

    if FirstRootNodesPool <> nil then
      FirstRootNodeIndex := FirstRootNodesPool.IndexOf(FModelFileNames[0]) else
      FirstRootNodeIndex := -1;
    OwnsFirstRootNode := FirstRootNodeIndex = -1;
    if not OwnsFirstRootNode then
      RootNodes[0] := FirstRootNodesPool.Objects[FirstRootNodeIndex] as TVRMLNode else
      RootNodes[0] := LoadVRML(FModelFileNames[0], false);

    for I := 1 to RootNodes.Count - 1 do
      RootNodes[I] := LoadVRML(FModelFileNames[I], false);

    Result := TVRMLGLAnimation.CreateCustomCache(nil, FCache);
    Result.Load(RootNodes, OwnsFirstRootNode, FTimes,
      FScenesPerTime, FEqualityEpsilon);
    Result.TimeLoop := FTimeLoop;
    Result.TimeBackwards := FTimeBackwards;

  finally
    FreeAndNil(RootNodes)
  end;
end;

end.
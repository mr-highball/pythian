(*
MIT License

Copyright (c) 2026 mr-highball

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
*)
unit pythian.workspace.tabs;

{$mode delphi}
{$H+}

interface

uses JS, Web;

type
  { Big Boss: navigation changes presentation only; mounted tools keep their state. }
  TWorkspaceTabs = class
  private
    function Click(AEvent: TJSMouseEvent): Boolean;
    function Key(AEvent: TJSKeyboardEvent): Boolean;
    function HashChange(AEvent: TEventListenerEvent): Boolean;
  public
    constructor Create;
    destructor Destroy; override;
  end;

procedure SelectWorkspacePane(const AId: String; AFocus: Boolean = False);
procedure RevealWorkspaceControl(AControl: TJSElement);
procedure ConfigureWorkspaceTabs(ARoot: TJSElement);

implementation

procedure SelectWorkspacePane(const AId: String; AFocus: Boolean);
var
  LButton: TJSElement;
  LButtons: TJSNodeList;
  LItem: TJSElement;
  LPane: TJSElement;
  LIndex: Integer;
  LSelected: Boolean;
begin
  LButton := document.querySelector('[role="tab"][aria-controls="' + AId + '"]');
  if LButton = nil then
  begin
    Exit;
  end;
  LButtons := LButton.parentElement.querySelectorAll('[role="tab"]');
  for LIndex := 0 to LButtons.length - 1 do
  begin
    LItem := TJSElement(LButtons[LIndex]);
    LPane := document.getElementById(LItem.getAttribute('aria-controls'));
    LSelected := LItem = LButton;
    if LSelected then
    begin
      LItem.setAttribute('aria-selected', 'true');
      LItem.setAttribute('tabindex', '0');
      LPane.removeAttribute('hidden');
    end
    else
    begin
      LItem.setAttribute('aria-selected', 'false');
      LItem.setAttribute('tabindex', '-1');
      LPane.setAttribute('hidden', '');
    end;
  end;
  if AFocus and (LButton.closest('[hidden]') = nil) then
  begin
    TJSHTMLElement(LButton).focus;
    TJSHTMLElement(LButton.parentElement).scrollIntoView;
  end;
end;

procedure RevealWorkspaceControl(AControl: TJSElement);
begin
  if AControl = nil then
  begin
    Exit;
  end;
  RevealWorkspaceControl(AControl.parentElement);
  if AControl.getAttribute('role') = 'tabpanel' then
  begin
    SelectWorkspacePane(AControl.id);
  end;
end;

procedure ConfigureWorkspaceTabs(ARoot: TJSElement);
var
  LGroups: TJSNodeList;
  LButtons: TJSNodeList;
  LButton: TJSElement;
  LPane: TJSElement;
  LIndex: Integer;
  LChild: Integer;
begin
  LGroups := ARoot.querySelectorAll('[data-tab-group]');
  for LIndex := 0 to LGroups.length - 1 do
  begin
    TJSElement(LGroups[LIndex]).setAttribute('role', 'tablist');
    LButtons := TJSElement(LGroups[LIndex]).querySelectorAll('button');
    for LChild := 0 to LButtons.length - 1 do
    begin
      LButton := TJSElement(LButtons[LChild]);
      LButton.setAttribute('role', 'tab');
      LPane := document.getElementById(LButton.getAttribute('aria-controls'));
      LPane.setAttribute('role', 'tabpanel');
      LPane.setAttribute('tabindex', '0');
      LPane.setAttribute('aria-labelledby', LButton.id);
    end;
    SelectWorkspacePane(TJSElement(LButtons[0]).getAttribute('aria-controls'));
  end;
end;

constructor TWorkspaceTabs.Create;
begin
  inherited Create;
  ConfigureWorkspaceTabs(document.body);
  document.addEventListener('click', @Click);
  document.addEventListener('keydown', @Key);
  window.addEventListener('hashchange', @HashChange);
  if window.location.hash <> '' then
  begin
    RevealWorkspaceControl(document.getElementById(Copy(window.location.hash, 2)));
  end;
end;

destructor TWorkspaceTabs.Destroy;
begin
  document.removeEventListener('click', @Click);
  document.removeEventListener('keydown', @Key);
  window.removeEventListener('hashchange', @HashChange);
  inherited Destroy;
end;

function TWorkspaceTabs.HashChange(AEvent: TEventListenerEvent): Boolean;
var
  LTarget: TJSElement;
begin
  Result := True;
  LTarget := document.getElementById(Copy(window.location.hash, 2));
  if LTarget <> nil then
  begin
    RevealWorkspaceControl(LTarget);
    TJSHTMLElement(LTarget).focus;
    TJSHTMLElement(LTarget).scrollIntoView;
  end;
end;

function TWorkspaceTabs.Click(AEvent: TJSMouseEvent): Boolean;
var
  LButton: TJSElement;
  LId: String;
begin
  Result := True;
  LButton := TJSElement(AEvent.target).closest('[role="tab"], [data-open-pane]');
  if LButton = nil then
  begin
    Exit;
  end;
  if LButton.hasAttribute('data-open-pane') then
  begin
    LId := LButton.getAttribute('data-open-pane');
  end
  else
  begin
    LId := LButton.getAttribute('aria-controls');
  end;
  RevealWorkspaceControl(document.getElementById(LId));
  SelectWorkspacePane(LId, True);
end;

function TWorkspaceTabs.Key(AEvent: TJSKeyboardEvent): Boolean;
var
  LButton: TJSElement;
  LButtons: TJSNodeList;
  LIndex: Integer;
begin
  Result := True;
  LButton := TJSElement(AEvent.target);
  if LButton.getAttribute('role') <> 'tab' then
  begin
    Exit;
  end;
  if (AEvent.key <> 'ArrowRight') and (AEvent.key <> 'ArrowLeft') and
    (AEvent.key <> 'Home') and (AEvent.key <> 'End') then
  begin
    Exit;
  end;
  LButtons := LButton.parentElement.querySelectorAll('[role="tab"]');
  LIndex := 0;
  while (LIndex < LButtons.length - 1) and (LButtons[LIndex] <> LButton) do
  begin
    Inc(LIndex);
  end;
  if AEvent.key = 'Home' then
  begin
    LIndex := 0;
  end
  else if AEvent.key = 'End' then
  begin
    LIndex := LButtons.length - 1;
  end
  else if AEvent.key = 'ArrowRight' then
  begin
    LIndex := (LIndex + 1) mod LButtons.length;
  end
  else
  begin
    LIndex := (LIndex + LButtons.length - 1) mod LButtons.length;
  end;
  LButton := TJSElement(LButtons[LIndex]);
  SelectWorkspacePane(LButton.getAttribute('aria-controls'));
  TJSHTMLElement(LButton).focus;
  AEvent.preventDefault;
end;

end.

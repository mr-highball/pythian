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
unit pythian.workspace.guide;

{$mode delphi}
{$H+}
{$modeswitch externalclass}

interface

uses
  JS,
  Web,
  SysUtils,
  pythian.workspace.tabs;

type
  { Presentation only. Reading a lesson never performs a project, media or job
    action. All three applications consume this one guide and its destinations. }
  TGuideDialog = class external name 'HTMLDialogElement' (TJSHTMLElement)
    open: Boolean;
    procedure showModal;
    procedure close;
  end;

  TWorkspaceGuide = class
  private
    FPage: String;
    FTopic: Integer;
    FOpen: Boolean;
    FStorage: Boolean;
    FRoot: TJSElement;
    FPanel: TJSElement;
    FOrigin: TJSElement;
    FScrollX: NativeInt;
    FScrollY: NativeInt;
    FOverflow: String;
    FTitle: TJSElement;
    FProgress: TJSElement;
    FTry: TJSElement;
    FExpect: TJSElement;
    FDone: TJSElement;
    FToggle: TJSElement;
    FPrevious: TJSElement;
    FNext: TJSElement;
    FShow: TJSElement;
    FNotice: TJSElement;
    FReturn: TJSElement;
    FHighlight: TJSElement;
    FTopics: TJSHTMLSelectElement;
    function Add(AParent: TJSElement; const ATag, AText, AClass: String): TJSElement;
    function Button(AParent: TJSElement; const AText, AAction: String): TJSElement;
    procedure Remember;
    procedure Draw;
    procedure FocusGuide;
    procedure ClearHighlight;
    procedure ShowControl;
    function Click(AEvent: TJSMouseEvent): Boolean;
    function ContextHelp(AEvent: TJSMouseEvent): Boolean;
    function SelectTopic(AEvent: TEventListenerEvent): Boolean;
    function Key(AEvent: TJSKeyboardEvent): Boolean;
  public
    constructor Create(const APage: String);
    destructor Destroy; override;
    procedure OpenTopic(const AId: String);
  end;

implementation

type
  TGuideLesson = record
    Id: String;
    Title: String;
    Action: String;
    Expectation: String;
    DoneWhen: String;
    Page: String;
    Target: String;
    Prerequisite: String;
  end;

const
  CPlace = 'pythian.guide.place.v1';

  CLessons: array[0..11] of TGuideLesson = (
    (Id: 'choose'; Title: 'Find music in Library';
     Action: 'Search your music or choose a collection. Play previews a track. Add puts it in your playlist. Add music imports a WAV; Record opens microphone recording. Music folder shows where to put your private tracks.';
     Expectation: 'Playing does not select music for learning. The clips button lists saved excerpts from that track, including clips made in other playlists. Your recordings stay on this computer.';
     DoneWhen: 'Open Selection to choose which whole tracks or clips will teach Pythian.';
     Page: 'studio'; Target: 'tracks'; Prerequisite: 'Connect to Studio and add or import a recording first.'),
    (Id: 'select'; Title: 'Choose whole tracks or clips';
     Action: 'In Selection, leave Whole track checked or switch it off and choose clips. Choose clip creates a new passage. Each included clip appears under its parent track. Use the track''s clips button in Library to find an older saved clip.';
     Expectation: 'Everything marked for learning teaches the next track. Whole track takes priority and hides its clip rows. Removing a clip from this playlist keeps its saved file. Choices save automatically.';
     DoneWhen: 'The selected duration and included tracks or clips match what you want to learn from.';
     Page: 'studio'; Target: 'playlist-tracks'; Prerequisite: 'Add music in Library before choosing whole tracks or clips.'),
    (Id: 'generate'; Title: 'Generate your first track';
     Action: 'Open Generate, choose Track length and Unit, then Generate music. Track influence gives each recording more or less learning weight. Use a saved style skips new recording analysis.';
     Expectation: 'Experimental: Pythian learns musical proposals from the included audio, WFC arranges notes and percussion, and Pythian instruments perform them. This does not recover isolated instruments from a mix. The job runs on the computer if your phone page closes; return to reconnect or Stop generation.';
     DoneWhen: 'Your new track is ready. Press Play, or open Hear individual parts. Save to playlist names the result; Download WAV saves it to your device.';
     Page: 'studio'; Target: 'output-duration'; Prerequisite: 'In a musical experiment, use Experiment settings or Back to playlist to return to Track length. Otherwise choose learning material or a saved style first.'),
    (Id: 'refine'; Title: 'Listen and change one thing';
     Action: 'Open a finished song and listen to its mix or individual parts. Change notes edits musical choices; Sounds & effects edits instruments while keeping the saved notes. Create a new version, then compare Before and After.';
     Expectation: 'Compare an original excerpt gives reference context, with its own timing. Save to playlist keeps this exact result. Listening reviews ask a specific development question; saving that answer does not retrain or generate.';
     DoneWhen: 'You know what changed and whether it helped. Keep the earlier version and feedback too.';
     Page: 'studio'; Target: 'generation-result'; Prerequisite: 'Generate a track, or open Songs and choose Open result first.'),
    (Id: 'record'; Title: 'Bring in a sound';
     Action: 'In Library, choose Add music or Record. Choose a WAV, or Start microphone then Stop recording. Add to library keeps the recording. Earlier inputs & analysis contains the optional Inspect audio tools.';
     Expectation: 'A phone microphone needs the local HTTPS page. Adding music to a collection makes it available in Library; it does not automatically include it in your learning selection. Your original stays intact.';
     DoneWhen: 'You can hear the input, see its analysis and find any saved copy in your collection.';
     Page: 'studio'; Target: 'studio-capture'; Prerequisite: 'In Library, open Add music or Record first. Showing controls never starts your microphone.'),
    (Id: 'clips'; Title: 'Make and reuse a clip';
     Action: 'In Selection, choose Choose clip on a track. Tap the waveform to seek, drag a range, or enter Start and End. Hear clip previews the range. Use this clip saves and includes it. Labels are optional.';
     Expectation: 'The waveform window does not limit clip length. Zoom, Whole track and View length reveal more. Each saved clip gets an independent WAV linked to its original time. Future learning reads that clip, without rescanning its entire parent.';
     DoneWhen: 'The clip appears under its parent in Selection and in the track''s clips list in Library.';
     Page: 'studio'; Target: 'source-start'; Prerequisite: 'In Selection, choose Choose clip or Edit clip on a track first.'),
    (Id: 'analysis'; Title: 'Explore what Pythian hears';
     Action: 'Open Choose clip, expand More tools, and choose Analyze at playhead. Inspect the suggestions and Beat overlay. Imported or recorded audio has its own Inspect audio tools and Experimental note/MIDI preview.';
     Expectation: 'Experimental suggestions can be wrong. Analysis covers up to 30 seconds; pitch suggestions use the first 8 seconds of that range and omit unmeasured edges. A mix is not separated into instruments. Suggestions do not change generation settings or train a style.';
     DoneWhen: 'You can compare the original with the preview and describe where the analysis agrees or fails.';
     Page: 'studio'; Target: 'source-beat-layer'; Prerequisite: 'Open Choose clip on a recording first. Preparation may be needed before analysis.'),
    (Id: 'effects'; Title: 'Shape a sound without losing the original';
     Action: 'Open Choose clip, expand More tools, prepare analysis & effects if requested, then open Effects. Add stages, adjust their order and settings, and preview. Save to collection when useful. To change generated instruments, use Sounds & effects on a finished song.';
     Expectation: 'Effects run in order, so changing their order can change the sound. Delay and reverb can add a tail after the passage. A saved version keeps its source connection; processing it does not make it an independent recording.';
     DoneWhen: 'You can hear the preview and find the saved version in Library. Add that version explicitly to learn from it.';
     Page: 'studio'; Target: 'studio-effects'; Prerequisite: 'Open Choose clip first, then prepare the recording if Effects requests it.'),
    (Id: 'long'; Title: 'Make a longer track';
     Action: 'In Generate, set Track length and Unit to seconds, minutes or hours. Generate music starts a host job. Stop generation cancels it; leaving the phone page does not cancel. Return to reconnect.';
     Expectation: 'Experimental: requests support 2 seconds to 24 hours of music plus the sound tail. Work and disk use increase with duration. The saved mix and six parts use bounded native processing. A full 24-hour render has not been tested.';
     DoneWhen: 'Play the completed track, seek through it, and Save to playlist or Download WAV.';
     Page: 'studio'; Target: 'output-duration'; Prerequisite: 'In a musical experiment, use Experiment settings or Back to playlist. Choose learning material or a saved style for ordinary generation.'),
    (Id: 'source-review'; Title: 'Check an observation in an original';
     Action: 'Open a question in Source reviews. Read what it asks, play the original, then answer that question. If a point or range is requested, use source time to place it and save. Choose uncertainty when you cannot tell.';
     Expectation: 'This checks an observation such as a note or beat in an original recording. It is separate from judging generated music. No pending question means no labeling is needed. Developer checks are optional app tests.';
     DoneWhen: 'The answer is shown as saved and the queue updates. You do not need to annotate every recording to use Studio.';
     Page: 'source'; Target: 'source-requests'; Prerequisite: 'Wait for the review queue to connect. Only assigned questions need an answer.'),
    (Id: 'listening-review'; Title: 'Review a saved musical result';
     Action: 'Read the one question. Compare Before and After at the same position; Hear selects the mix or an individual part. Press Play after switching. Original has its own source timing. Choose an answer or Unsure, then Save & next. A note is optional.';
     Expectation: 'Each prepared experiment explains what changed and which core decision your answer guides. No new recording, segmentation or generation setup is needed. Saving records your judgment for the next development step. It does not automatically train a preference model.';
     DoneWhen: 'Save moves the question to Completed reviews. Choose review opens that list so you can reopen your answer.';
     Page: 'listening'; Target: 'packet'; Prerequisite: 'Choose a review if no question is open. An empty queue means there are no assigned listening questions.'),
    (Id: 'settings'; Title: 'Understand generation settings';
     Action: 'The main flow only needs music selection and track length. Track influence changes learning weight. Use a saved style reuses its providers and sounds. More music controls opens optional musical experiments. Analyze audio, then Try these suggestions to edit recording ideas.';
     Expectation: 'Experiments use authored examples or your edited recording ideas. They keep your playlist saved. Use in experiment saves choices; only Generate experiment makes music. Recording ideas are Experimental and do not separate a mix into instruments.';
     DoneWhen: 'You know whether the next track learns your selection, reuses a style or runs a musical experiment.';
     Page: 'studio'; Target: 'open-laboratory'; Prerequisite: 'Connect to Studio before opening More music controls in Generate.')
  );

function TWorkspaceGuide.Add(AParent: TJSElement;
  const ATag, AText, AClass: String): TJSElement;
begin
  Result := document.createElement(ATag);
  Result.textContent := AText;
  Result.className := AClass;
  AParent.appendChild(Result);
end;

function TWorkspaceGuide.Button(AParent: TJSElement;
  const AText, AAction: String): TJSElement;
begin
  Result := Add(AParent, 'button', AText, 'guide-button');
  Result.setAttribute('type', 'button');
  Result.setAttribute('data-guide-action', AAction);
end;

constructor TWorkspaceGuide.Create(const APage: String);
var
  LMount: TJSElement;
  LBar: TJSElement;
  LRow: TJSElement;
  LOption: TJSElement;
  LIcon: TJSElement;
  LPath: TJSElement;
  LIndex: Integer;
  LSaved: String;
  LQuery: String;
begin
  inherited Create;
  FPage := APage;
  FStorage := True;
  if APage = 'source' then
  begin
    FTopic := 9;
  end
  else if APage = 'listening' then
  begin
    FTopic := 10;
  end;
  try
    LSaved := window.localStorage.getItem(CPlace);
    for LIndex := 0 to High(CLessons) do
    begin
      if LSaved = CLessons[LIndex].Id then
      begin
        FTopic := LIndex;
      end;
    end;
  except
    FStorage := False;
  end;
  LQuery := window.location.search;
  for LIndex := 0 to High(CLessons) do
  begin
    if LQuery = '?guide=' + CLessons[LIndex].Id then
    begin
      FTopic := LIndex;
      FOpen := True;
      { The link opens a lesson once. Leaving it in the URL would reopen a
        dismissed guide on every reload. No unrelated query is accepted here. }
      window.history.replaceState(nil, '', window.location.pathname + window.location.hash);
    end;
  end;
  LMount := document.getElementById('workspace-navigation');
  FRoot := Add(LMount, 'section', '', 'workspace-guide');
  FRoot.setAttribute('aria-label', 'Pythian help');
  LBar := Add(FRoot, 'div', '', 'guide-bar');
  FToggle := Button(LBar, '', 'toggle');
  FToggle.id := 'guide-toggle';
  FToggle.setAttribute('aria-controls', 'guide-panel');
  FToggle.setAttribute('aria-haspopup', 'dialog');
  LIcon := document.createElementNS('http://www.w3.org/2000/svg', 'svg');
  LIcon.setAttribute('viewBox', '0 0 24 24');
  LIcon.setAttribute('aria-hidden', 'true');
  LPath := document.createElementNS('http://www.w3.org/2000/svg', 'path');
  LPath.setAttribute('d', 'M12 5v15M12 5C8 2 4 3 2 4v15c4-2 7-1 10 1 3-2 6-3 10-1V4c-2-1-6-2-10 1Z');
  LIcon.appendChild(LPath);
  FToggle.appendChild(LIcon);
  Add(FToggle, 'span', 'Learn to teach Pythian', '');
  Add(LBar, 'span', 'A quick start + help with each tool', 'guide-intro');
  FPanel := Add(FRoot, 'dialog', '', 'guide-panel');
  FPanel.setAttribute('aria-modal', 'true');
  LRow := Add(FPanel, 'div', '', 'guide-dialog-header');
  Add(LRow, 'strong', 'Pythian help', '');
  Button(LRow, 'Close help', 'close');
  FPanel.id := 'guide-panel';
  Add(FPanel, 'label', 'Learn about', '').setAttribute('for', 'guide-topic');
  FTopics := TJSHTMLSelectElement(Add(FPanel, 'select', '', ''));
  FTopics.id := 'guide-topic';
  for LIndex := 0 to High(CLessons) do
  begin
    LSaved := CLessons[LIndex].Title;
    if LIndex < 4 then
    begin
      LSaved := IntToStr(LIndex + 1) + '. ' + LSaved;
    end;
    LOption := Add(FTopics, 'option', LSaved, '');
    LOption.setAttribute('value', IntToStr(LIndex));
  end;
  FProgress := Add(FPanel, 'p', '', 'guide-progress');
  FTitle := Add(FPanel, 'h2', '', '');
  FTitle.id := 'guide-title';
  FTitle.setAttribute('tabindex', '-1');
  FPanel.setAttribute('aria-labelledby', 'guide-title');
  Add(FPanel, 'h3', 'Try this', '');
  FTry := Add(FPanel, 'p', '', '');
  Add(FPanel, 'h3', 'What to expect', '');
  FExpect := Add(FPanel, 'p', '', '');
  FDone := Add(FPanel, 'p', '', 'guide-result');
  FShow := Button(FPanel, 'Show me the controls', 'show');
  FShow.classList.add('guide-primary');
  FNotice := Add(FPanel, 'p', '', 'guide-notice');
  FNotice.setAttribute('role', 'status');
  LRow := Add(FPanel, 'div', '', 'guide-actions');
  FPrevious := Button(LRow, 'Previous lesson', 'previous');
  FNext := Button(LRow, 'Next lesson', 'next');
  Button(LRow, 'Close guide', 'close');
  LRow := Add(FPanel, 'details', '', 'guide-more');
  Add(LRow, 'summary', 'About this guide', '');
  Add(LRow, 'p', 'This browser remembers your reading position when available. Reading or showing controls never plays, records, generates or saves feedback. You choose when to start those actions.', '');
  Button(LRow, 'Restart quick start', 'restart');
  FReturn := Button(FRoot, 'Back to guide', 'return');
  FReturn.addEventListener('click', @Click);
  FReturn.classList.add('guide-return');
  FReturn.setAttribute('hidden', '');
  FRoot.addEventListener('click', @Click);
  FRoot.addEventListener('keydown', @Key);
  FTopics.addEventListener('change', @SelectTopic);
  document.addEventListener('click', @ContextHelp);
  Draw;
end;

destructor TWorkspaceGuide.Destroy;
begin
  FOpen := False;
  Draw;
  ClearHighlight;
  FRoot.removeEventListener('click', @Click);
  FRoot.removeEventListener('keydown', @Key);
  FReturn.removeEventListener('click', @Click);
  FReturn.remove;
  FTopics.removeEventListener('change', @SelectTopic);
  document.removeEventListener('click', @ContextHelp);
  FRoot.remove;
  inherited Destroy;
end;

procedure TWorkspaceGuide.Remember;
begin
  try
    window.localStorage.setItem(CPlace, CLessons[FTopic].Id);
  except
    FStorage := False;
  end;
end;

procedure TWorkspaceGuide.Draw;
begin
  FTopics.value := IntToStr(FTopic);
  FTitle.textContent := CLessons[FTopic].Title;
  FTry.textContent := CLessons[FTopic].Action;
  FExpect.textContent := CLessons[FTopic].Expectation;
  FDone.textContent := 'Ready to move on: ' + CLessons[FTopic].DoneWhen;
  if FTopic < 4 then
  begin
    FProgress.textContent := 'QUICK START · LESSON ' + IntToStr(FTopic + 1) + ' OF 4';
  end
  else
  begin
    FProgress.textContent := 'TOOL GUIDE';
  end;
  TJSHTMLButtonElement(FPrevious).disabled := FTopic = 0;
  if FTopic = 3 then
  begin
    FNext.textContent := 'Finish reading';
  end
  else if FTopic >= 4 then
  begin
    FNext.textContent := 'Quick start';
  end
  else
  begin
    FNext.textContent := 'Next lesson';
  end;
  if FPage = CLessons[FTopic].Page then
  begin
    FShow.textContent := 'Show me the controls';
  end
  else if CLessons[FTopic].Page = 'studio' then
  begin
    FShow.textContent := 'Continue in Studio';
  end
  else if CLessons[FTopic].Page = 'source' then
  begin
    FShow.textContent := 'Go to Source reviews';
  end
  else
  begin
    FShow.textContent := 'Go to Listening reviews';
  end;
  if FOpen then
  begin
    if not TGuideDialog(FPanel).open then
    begin
      FOrigin := document.activeElement;
      FScrollX := window.scrollX;
      FScrollY := window.scrollY;
      FOverflow := TJSHTMLElement(document.documentElement).style.getPropertyValue('overflow');
      TJSHTMLElement(document.documentElement).style.setProperty('overflow', 'hidden');
      TGuideDialog(FPanel).showModal;
    end;
    FToggle.setAttribute('aria-expanded', 'true');
  end
  else
  begin
    if TGuideDialog(FPanel).open then
    begin
      TGuideDialog(FPanel).close;
      TJSHTMLElement(document.documentElement).style.setProperty('overflow', FOverflow);
      if (FOrigin <> nil) and document.body.contains(FOrigin) then
      begin
        TJSHTMLElement(FOrigin).focus;
      end;
      window.scrollTo(FScrollX, FScrollY);
    end;
    FToggle.setAttribute('aria-expanded', 'false');
    ClearHighlight;
  end;
  FNotice.textContent := '';
  if not FStorage then
  begin
    FNotice.textContent := 'The guide works, but this browser cannot remember your place.';
  end;
end;

procedure TWorkspaceGuide.FocusGuide;
begin
  ClearHighlight;
  TJSHTMLElement(FTitle).focus;
  TJSHTMLElement(FPanel).scrollTop := 0;
end;

procedure TWorkspaceGuide.ClearHighlight;
begin
  if FHighlight <> nil then
  begin
    FHighlight.classList.remove('guide-highlight');
  end;
  FHighlight := nil;
  if FReturn <> nil then
  begin
    FReturn.setAttribute('hidden', '');
  end;
end;

procedure TWorkspaceGuide.ShowControl;
var
  LTarget: TJSElement;
  LParent: TJSElement;
  LUnavailable: Boolean;
  LPath: String;
begin
  if FPage <> CLessons[FTopic].Page then
  begin
    if CLessons[FTopic].Page = 'studio' then
    begin
      LPath := '/studio.html';
    end
    else if CLessons[FTopic].Page = 'source' then
    begin
      LPath := '/';
    end
    else
    begin
      LPath := '/listen.html';
    end;
    Remember;
    window.location.href := LPath + '?guide=' + CLessons[FTopic].Id;
    Exit;
  end;
  ClearHighlight;
  LTarget := document.getElementById(CLessons[FTopic].Target);
  RevealWorkspaceControl(LTarget);
  LUnavailable := LTarget = nil;
  LParent := LTarget;
  while LParent <> nil do
  begin
    if LParent.hasAttribute('hidden') or LParent.hasAttribute('disabled') or
      ((LowerCase(LParent.tagName) = 'dialog') and not LParent.hasAttribute('open')) then
    begin
      LUnavailable := True;
    end;
    LParent := LParent.parentElement;
  end;
  if LUnavailable then
  begin
    FNotice.textContent := CLessons[FTopic].Prerequisite;
    FNotice.setAttribute('tabindex', '-1');
    TJSHTMLElement(FNotice).focus;
    TJSHTMLElement(FNotice).scrollIntoView;
    Exit;
  end
  else
  begin
    FNotice.textContent := 'Controls highlighted. Use Back to guide to return.';
  end;
  if LTarget = nil then
  begin
    Exit;
  end;
  LParent := LTarget;
  while LParent <> nil do
  begin
    if LowerCase(LParent.tagName) = 'details' then
    begin
      LParent.setAttribute('open', '');
    end;
    LParent := LParent.parentElement;
  end;
  if not LTarget.hasAttribute('tabindex') and
    (LTarget.tagName <> 'INPUT') and (LTarget.tagName <> 'SELECT') and
    (LTarget.tagName <> 'BUTTON') then
  begin
    LTarget.setAttribute('tabindex', '-1');
  end;
  FOpen := False;
  Draw;
  FHighlight := LTarget;
  FHighlight.classList.add('guide-highlight');
  TJSHTMLElement(LTarget).focus;
  TJSHTMLElement(LTarget).scrollIntoView;
  { Big Boss: a return button outside an open tool dialog would be inert. }
  LParent := LTarget.closest('dialog[open]');
  if LParent = nil then LParent := FRoot;
  LParent.appendChild(FReturn);
  FReturn.removeAttribute('hidden');
  FReturn.textContent := 'Back to guide';
end;

function TWorkspaceGuide.Click(AEvent: TJSMouseEvent): Boolean;
var
  LTarget: TJSElement;
  LAction: String;
begin
  Result := True;
  if AEvent.currentTarget = FReturn then AEvent.stopPropagation;
  LTarget := TJSElement(AEvent.target).closest('[data-guide-action]');
  if LTarget = nil then
  begin
    Exit;
  end;
  LAction := LTarget.getAttribute('data-guide-action');
  if LAction = 'show' then
  begin
    ShowControl;
    Exit;
  end;
  if LAction = 'return' then
  begin
    FOpen := True;
    Draw;
    if FHighlight <> nil then
    begin
      FOrigin := FHighlight;
    end;
    FocusGuide;
    Exit;
  end;
  if LAction = 'toggle' then
  begin
    FOpen := not FOpen;
  end
  else if LAction = 'close' then
  begin
    FOpen := False;
  end
  else if LAction = 'restart' then
  begin
    FTopic := 0;
  end
  else if (LAction = 'previous') and (FTopic > 0) then
  begin
    Dec(FTopic);
  end
  else if LAction = 'next' then
  begin
    if FTopic = 3 then
    begin
      FNotice.textContent := 'Try the cycle with your own music, or choose a tool lesson above. Playlist choices save automatically; listening answers need Save & next.';
      Exit;
    end
    else if FTopic >= 4 then
    begin
      FTopic := 0;
    end
    else
    begin
      Inc(FTopic);
    end;
  end;
  Remember;
  Draw;
  if FOpen then
  begin
    FocusGuide;
  end;
end;

function TWorkspaceGuide.ContextHelp(AEvent: TJSMouseEvent): Boolean;
var
  LTarget: TJSElement;
begin
  Result := True;
  LTarget := TJSElement(AEvent.target).closest('[data-guide-topic]');
  if LTarget = nil then
  begin
    Exit;
  end;
  OpenTopic(LTarget.getAttribute('data-guide-topic'));
end;

procedure TWorkspaceGuide.OpenTopic(const AId: String);
var
  LIndex: Integer;
begin
  for LIndex := 0 to High(CLessons) do
  begin
    if AId = CLessons[LIndex].Id then
    begin
      FTopic := LIndex;
      FOpen := True;
      Remember;
      Draw;
      FocusGuide;
      Exit;
    end;
  end;
end;

function TWorkspaceGuide.SelectTopic(AEvent: TEventListenerEvent): Boolean;
var
  LTopic: Integer;
begin
  Result := True;
  if not TryStrToInt(FTopics.value, LTopic) or (LTopic < 0) or
    (LTopic > High(CLessons)) then
  begin
    Exit;
  end;
  FTopic := LTopic;
  Remember;
  Draw;
  FocusGuide;
end;

function TWorkspaceGuide.Key(AEvent: TJSKeyboardEvent): Boolean;
begin
  Result := True;
  if (AEvent.key = 'Escape') and FOpen then
  begin
    FOpen := False;
    Remember;
    Draw;
    AEvent.preventDefault;
  end;
end;

end.

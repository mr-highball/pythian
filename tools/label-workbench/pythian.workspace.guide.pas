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

interface

uses
  JS,
  Web,
  SysUtils;

type
  { Presentation only. Reading a lesson never performs a project, media or job
    action. All three applications consume this one guide and its destinations. }
  TWorkspaceGuide = class
  private
    FPage: String;
    FTopic: Integer;
    FOpen: Boolean;
    FStorage: Boolean;
    FRoot: TJSElement;
    FPanel: TJSElement;
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
  COpen = 'pythian.guide.open.v1';
  CLessons: array[0..11] of TGuideLesson = (
    (Id: 'choose'; Title: 'Choose what to carry forward';
     Action: 'Name a project. Browse a collection, open Listen & select, and add a whole recording or passages you like. Describe each selection in your own words, then Save draft.';
     Expectation: 'These selections are your corpus: the examples for this project. Choose material that expresses your intent. Labels such as warm or sparse describe your choices; they do not yet act as generation commands.';
     DoneWhen: 'Your saved project lists the intended recordings, ranges and descriptions.';
     Page: 'studio'; Target: 'style-name'; Prerequisite: 'Wait for the catalog to connect before naming or saving a project.'),
    (Id: 'generate'; Title: 'Make a small first experiment';
     Action: 'With a saved project, open Save short auditions to compare. Choose two 20-second auditions, Check setup, then Generate auditions. If asked, choose Development and exploration.';
     Expectation: 'Experimental: the current mode rearranges short pieces of your selected audio through WFC. Longer sources can supply more examples, but do not by themselves teach notes, song structure or a complete style. Source length and output length are separate.';
     DoneWhen: 'Finished auditions appear in Generation history. Check source coverage there to see what was actually used.';
     Page: 'studio'; Target: 'batch-duration'; Prerequisite: 'Select recordings and Save draft first. Then these generation controls become available.'),
    (Id: 'listen'; Title: 'Tell Pythian what you hear';
     Action: 'In New comparison, choose your finished auditions and Start listening. Judge style fit, flow, repetition and sound quality. Choose what you would keep, or neither. Add a note at a useful moment, then Save feedback.';
     Expectation: 'A useful answer can be: the texture fits, but the join at 0:12 clicks. Use Cannot judge yet when unsure. Hide sample identities for a comparison without knowing which settings made each take.';
     DoneWhen: 'Reload saved feedback and see your answers again. A bad result is useful feedback too.';
     Page: 'studio'; Target: 'review-output-a'; Prerequisite: 'Generate saved auditions first, then select them for a comparison.'),
    (Id: 'refine'; Title: 'Change one thing and listen again';
     Action: 'After saving feedback, choose Use these settings for next batch. Change one source weight, source selection or generation setting. Check setup and Generate auditions, then compare with the earlier result.';
     Expectation: 'Saving feedback records your judgment; it does not automatically retrain. The next-batch action copies the reviewed setup and links the new experiment to it. A new seed makes another take; it does not add knowledge. Pin useful results to find them again.';
     DoneWhen: 'You can say what changed and whether it helped. Keep the earlier feedback, even when neither result works.';
     Page: 'studio'; Target: 'review-current'; Prerequisite: 'Open a comparison and Save feedback first; its next-batch buttons appear beside the samples.'),
    (Id: 'record'; Title: 'Bring in a sound';
     Action: 'Choose Record audio or Import WAV. For recording, Start microphone, allow access, then Stop recording. Analyze audio and play the preview. Save to collection only when you want to keep the input.';
     Expectation: 'A phone microphone needs a secure HTTPS page. Importing or recording prepares an input for exploration; saving it to a collection makes it available to projects. Your original stays intact.';
     DoneWhen: 'You can hear the input, see its analysis and find any saved copy in your collection.';
     Page: 'studio'; Target: 'start-record'; Prerequisite: 'Connect to Studio before importing or recording.'),
    (Id: 'select'; Title: 'Find and describe a passage';
     Action: 'Open a recording with Listen & select. Tap the waveform to seek, drag to select, or enter Start and End times. Zoom or change View length to see more. Add passage to project, then Save draft.';
     Expectation: 'The waveform view is a window onto the recording, not a duration limit. Add whole recording to project selects the full track. Preview browsing stays light; adding material prepares that recording for learning.';
     DoneWhen: 'Play the selected passage and check its start and end. Your saved project shows that range and its labels.';
     Page: 'studio'; Target: 'source-position'; Prerequisite: 'Choose a recording and open Listen & select first.'),
    (Id: 'analysis'; Title: 'Explore what Pythian hears';
     Action: 'Open a recording and expand Explore Pythian analysis for timing overlays. For an imported or recorded input, Analyze audio, open Try a note preview and try notes from the first 8 seconds. Download MIDI when available.';
     Expectation: 'Experimental: beat marks and detected pitches are suggestions. Listen for missed notes, extra notes and timing drift. MIDI represents detected note events; it does not reproduce the original voice or instrument.';
     DoneWhen: 'You can compare the original with the preview and describe where the analysis agrees or fails.';
     Page: 'studio'; Target: 'source-beat-layer'; Prerequisite: 'Open Listen & select for a recording first. Recording preparation may be needed for analysis.'),
    (Id: 'effects'; Title: 'Shape a sound without losing the original';
     Action: 'Open a recording, prepare it for analysis & effects, and expand Shape this passage with effects. Add effects, adjust their order and settings, then preview. Save the result to your collection when useful.';
     Expectation: 'Effects run in order, so changing their order can change the sound. Delay and reverb can add a tail after the passage. A saved version keeps its source connection; processing it does not make it an independent recording.';
     DoneWhen: 'The preview matches your intention and the saved version appears in the collection. Add that version to a project explicitly if you want to learn from it.';
     Page: 'studio'; Target: 'studio-effects'; Prerequisite: 'Open a recording with Listen & select first, then prepare it for effects.'),
    (Id: 'long'; Title: 'Listen as music is generated';
     Action: 'Save a project, choose a Length and Time unit under Generate and play, then start. Pause or Stop whenever you want. Save next 20 seconds for review captures a short upcoming excerpt.';
     Expectation: 'Experimental: output streams as it is made, up to 24 hours. Keep the page open. Only saved excerpts are retained as WAV files. Longer playback is not evidence of deeper learning or long-form musical quality.';
     DoneWhen: 'Playback responds to Pause and Stop. A saved excerpt can be opened from Listening reviews for feedback.';
     Page: 'studio'; Target: 'studio-live'; Prerequisite: 'Select your material and Save draft before starting live generation.'),
    (Id: 'source-review'; Title: 'Check an observation in an original';
     Action: 'Open a question in Source reviews. Read what it asks, play the original, then answer that question. If a point or range is requested, use source time to place it and save. Choose uncertainty when you cannot tell.';
     Expectation: 'This checks an observation such as a note or beat in an original recording. It is separate from judging generated music. No pending question means no labeling is needed. Developer checks are optional app tests.';
     DoneWhen: 'The answer is shown as saved and the queue updates. You do not need to annotate every recording to use Studio.';
     Page: 'source'; Target: 'source-requests'; Prerequisite: 'Wait for the review queue to connect. Only assigned questions need an answer.'),
    (Id: 'listening-review'; Title: 'Review a saved musical result';
     Action: 'Choose a review in Listening reviews, read its question and play each recording. Answer what you can, add a comment at the playhead if useful, and Save response.';
     Expectation: 'These are assigned listening questions and saved live excerpts. For your own batch comparisons and next-batch controls, use Listen and compare in Studio. Feedback records your judgment without silently starting training.';
     DoneWhen: 'The review moves to Completed reviews and your saved response can be reopened.';
     Page: 'listening'; Target: 'pending'; Prerequisite: 'Wait for the queue to connect. An empty queue means there are no assigned listening questions.'),
    (Id: 'settings'; Title: 'Understand generation settings';
     Action: 'Open Generation settings and source weights. A source weight changes a recording''s relative influence. Keep the seed to repeat a setup, or change it for a different take. Adjust one setting at a time.';
     Expectation: 'Sound examples to keep limits the types of short recorded pieces available. Neighboring pieces sets how much local sequence context the model considers. These controls do not specify instruments, notes, tempo or song sections.';
     DoneWhen: 'Before generating, you know which setting changed and what you want to listen for. Compare against an earlier saved audition.';
     Page: 'studio'; Target: 'batch-palette'; Prerequisite: 'Select recordings and Save draft before adjusting generation settings.')
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
    FOpen := window.localStorage.getItem(COpen) = 'yes';
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
  LIcon := document.createElementNS('http://www.w3.org/2000/svg', 'svg');
  LIcon.setAttribute('viewBox', '0 0 24 24');
  LIcon.setAttribute('aria-hidden', 'true');
  LPath := document.createElementNS('http://www.w3.org/2000/svg', 'path');
  LPath.setAttribute('d', 'M12 5v15M12 5C8 2 4 3 2 4v15c4-2 7-1 10 1 3-2 6-3 10-1V4c-2-1-6-2-10 1Z');
  LIcon.appendChild(LPath);
  FToggle.appendChild(LIcon);
  Add(FToggle, 'span', 'Learn to teach Pythian', '');
  Add(LBar, 'span', 'A guided project + help with each tool', 'guide-intro');
  FPanel := Add(FRoot, 'div', '', 'guide-panel');
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
  Add(LRow, 'p', 'Your reading position is remembered on this browser when available. Reading a lesson does not complete a project or save feedback. Show me only reveals controls; you decide when to play, record, generate or save.', '');
  Button(LRow, 'Restart first-project guide', 'restart');
  FReturn := Button(FRoot, 'Back to guide', 'return');
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
  ClearHighlight;
  FRoot.removeEventListener('click', @Click);
  FRoot.removeEventListener('keydown', @Key);
  FTopics.removeEventListener('change', @SelectTopic);
  document.removeEventListener('click', @ContextHelp);
  FRoot.remove;
  inherited Destroy;
end;

procedure TWorkspaceGuide.Remember;
begin
  try
    window.localStorage.setItem(CPlace, CLessons[FTopic].Id);
    if FOpen then
    begin
      window.localStorage.setItem(COpen, 'yes');
    end
    else
    begin
      window.localStorage.setItem(COpen, 'no');
    end;
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
    FProgress.textContent := 'FIRST PROJECT · LESSON ' + IntToStr(FTopic + 1) + ' OF 4';
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
    FNext.textContent := 'First-project guide';
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
    FPanel.removeAttribute('hidden');
    FToggle.setAttribute('aria-expanded', 'true');
  end
  else
  begin
    FPanel.setAttribute('hidden', '');
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
  TJSHTMLElement(FRoot).scrollIntoView;
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
  LUnavailable := LTarget = nil;
  LParent := LTarget;
  while LParent <> nil do
  begin
    if LParent.hasAttribute('hidden') or LParent.hasAttribute('disabled') then
    begin
      LUnavailable := True;
    end;
    LParent := LParent.parentElement;
  end;
  if (FTopic = 3) and (LTarget <> nil) then
  begin
    LUnavailable := LTarget.querySelector('[data-action="next"]') = nil;
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
  FHighlight := LTarget;
  FHighlight.classList.add('guide-highlight');
  TJSHTMLElement(LTarget).focus;
  TJSHTMLElement(LTarget).scrollIntoView;
  FReturn.removeAttribute('hidden');
  FReturn.textContent := 'Back to guide';
end;

function TWorkspaceGuide.Click(AEvent: TJSMouseEvent): Boolean;
var
  LTarget: TJSElement;
  LAction: String;
begin
  Result := True;
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
      FNotice.textContent := 'Guide read. Try the cycle with your own music, or choose a tool lesson above. Your project and feedback still use their own Save buttons.';
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
  end
  else
  begin
    TJSHTMLElement(FToggle).focus;
  end;
end;

function TWorkspaceGuide.ContextHelp(AEvent: TJSMouseEvent): Boolean;
var
  LTarget: TJSElement;
  LIndex: Integer;
begin
  Result := True;
  LTarget := TJSElement(AEvent.target).closest('[data-guide-topic]');
  if LTarget = nil then
  begin
    Exit;
  end;
  for LIndex := 0 to High(CLessons) do
  begin
    if LTarget.getAttribute('data-guide-topic') = CLessons[LIndex].Id then
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
    TJSHTMLElement(FToggle).focus;
    AEvent.preventDefault;
  end;
end;

end.

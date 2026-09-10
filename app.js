import { presets, buildPrompt, getFramePlan, getPresetTitle } from './prompt-engine.js';
import { supportedLanguages, optionGroups, normalizeLanguage, tOption, tUI, languageLabel } from './i18n.js';

const $ = (id) => document.getElementById(id);
const form = $('promptForm');

const fields = [
  'uiLanguage','promptLanguage','preset','modelTarget','subjectType','subject','situation','situationDetail',
  'action','motionMood','motionPath','actionDetail','style','view','background','direction','environmentDetail',
  'frameCount','gridLayout','lockIdentity','lockScale','lockBaseline','lockCamera','seamlessLoop','noText','noCrop',
  'noBleed','trueAlpha','extra'
];

const defaults = {
  uiLanguage:'ko-KR', promptLanguage:'en-US', preset:'combat', modelTarget:'ChatGPT Images 2.5',
  subjectType:'character', subject:'', situation:'standing', situationDetail:'', action:'attack', motionMood:'snappy',
  motionPath:'stationary', actionDetail:'', style:'pixel16', view:'side', background:'transparent', direction:'right',
  environmentDetail:'', frameCount:'16', gridLayout:'4x4', lockIdentity:true, lockScale:true, lockBaseline:true,
  lockCamera:true, seamlessLoop:true, noText:true, noCrop:true, noBleed:true, trueAlpha:true, extra:''
};

const optionIds = {
  preset:Object.keys(presets),
  subjectType:['character','creature','robot','vehicle','object'],
  situation:Object.values(optionGroups.situation).flat(),
  action:Object.values(optionGroups.action).flat(),
  mood:['still','slow','snappy','weighty','cute','dramatic','natural'],
  motionPath:['stationary','forward','backward','up','down','leftRight','arc','circle','zigzag'],
  style:['pixel16','pixel32','chibi','anime','clay','ink','realistic','silhouette'],
  view:['side','threequarter','front','back','topdown','isometric'],
  background:['transparent','white','studio','forest','city','interior','sky','underwater','stage','custom'],
  direction:['right','left','camera','away','adaptive']
};

function normalizeState(state={}){
  const out={...state};
  out.uiLanguage=normalizeLanguage(out.uiLanguage || defaults.uiLanguage);
  out.promptLanguage=normalizeLanguage(out.promptLanguage || defaults.promptLanguage);
  return out;
}

function stateFromForm(){
  const state={};
  for(const id of fields){
    const el=$(id);
    if(!el) continue;
    state[id]=el.type==='checkbox' ? el.checked : el.value;
  }
  return normalizeState(state);
}

function applyState(state){
  for(const id of fields){
    const el=$(id);
    if(!el || state[id]===undefined) continue;
    if(el.type==='checkbox') el.checked=Boolean(state[id]);
    else el.value=String(state[id]);
  }
}

function encodeState(state){
  return btoa(unescape(encodeURIComponent(JSON.stringify(state))))
    .replace(/\+/g,'-').replace(/\//g,'_').replace(/=+$/,'');
}

function decodeState(raw){
  try{
    const clean=raw.replace(/-/g,'+').replace(/_/g,'/');
    const padded=clean + '='.repeat((4-clean.length%4)%4);
    return normalizeState(JSON.parse(decodeURIComponent(escape(atob(padded)))));
  }catch{return null;}
}

function persist(state){
  localStorage.setItem('motionPromptLabState',JSON.stringify(state));
}

function toast(message){
  const el=$('toast');
  el.textContent=message;
  el.classList.add('show');
  clearTimeout(window.__toast);
  window.__toast=setTimeout(()=>el.classList.remove('show'),1800);
}

function initLanguageSelects(){
  for(const id of ['uiLanguage','promptLanguage']){
    const select=$(id);
    select.innerHTML='';
    for(const item of supportedLanguages){
      const option=document.createElement('option');
      option.value=item.code;
      option.textContent=item.label;
      select.appendChild(option);
    }
  }
}

function populateSelect(id, group, values, lang){
  const select=$(id);
  const current=select.value;
  select.innerHTML='';
  for(const value of values){
    const option=document.createElement('option');
    option.value=value;
    option.textContent=tOption(lang,group,value);
    select.appendChild(option);
  }
  if(values.includes(current)) select.value=current;
}

function populateSituationSelect(lang){
  const select=$('situation');
  const current=select.value;
  select.innerHTML='';
  for(const [groupName, values] of Object.entries(optionGroups.situation)){
    const optgroup=document.createElement('optgroup');
    optgroup.label=tOption(lang,'group',groupName);
    for(const value of values){
      const option=document.createElement('option');
      option.value=value;
      option.textContent=tOption(lang,'situation',value);
      optgroup.appendChild(option);
    }
    select.appendChild(optgroup);
  }
  if(optionIds.situation.includes(current)) select.value=current;
}

function populateActionSelect(lang){
  const select=$('action');
  const current=select.value;
  select.innerHTML='';
  for(const [groupName, values] of Object.entries(optionGroups.action)){
    const optgroup=document.createElement('optgroup');
    optgroup.label=tOption(lang,'group',groupName);
    for(const value of values){
      const option=document.createElement('option');
      option.value=value;
      option.textContent=tOption(lang,'action',value);
      optgroup.appendChild(option);
    }
    select.appendChild(optgroup);
  }
  if(optionIds.action.includes(current)) select.value=current;
}

function translateStaticUI(lang){
  document.documentElement.lang=lang;
  document.title=tUI(lang,'pageTitle');
  document.querySelectorAll('[data-i18n]').forEach(el=>{
    const key=el.dataset.i18n;
    el.textContent=tUI(lang,key);
  });
  document.querySelectorAll('[data-i18n-placeholder]').forEach(el=>{
    el.placeholder=tUI(lang,el.dataset.i18nPlaceholder);
  });
  $('themeToggle').setAttribute('aria-label',tUI(lang,'theme'));
  $('themeToggle').title=tUI(lang,'theme');
}

function applyUILanguage(lang){
  const l=normalizeLanguage(lang);
  translateStaticUI(l);
  populateSelect('preset','preset',optionIds.preset,l);
  populateSelect('subjectType','subjectType',optionIds.subjectType,l);
  populateSituationSelect(l);
  populateActionSelect(l);
  populateSelect('motionMood','mood',optionIds.mood,l);
  populateSelect('motionPath','motionPath',optionIds.motionPath,l);
  populateSelect('style','style',optionIds.style,l);
  populateSelect('view','view',optionIds.view,l);
  populateSelect('background','background',optionIds.background,l);
  populateSelect('direction','direction',optionIds.direction,l);
}

function render(){
  const state=stateFromForm();
  const prompt=buildPrompt(state);
  $('promptOutput').textContent=prompt;
  $('outputTitle').textContent=getPresetTitle(state.preset,state.uiLanguage);
  $('frameMeta').textContent=`${state.frameCount} frames · ${state.gridLayout} · ${languageLabel(state.promptLanguage)}`;
  const plan=getFramePlan(state.action,Number(state.frameCount),state.promptLanguage,state.actionDetail,state.situation);
  $('framePlan').innerHTML='';
  plan.forEach((p,i)=>{
    const li=document.createElement('li');
    li.textContent=`${String(i+1).padStart(2,'0')} · ${p}`;
    $('framePlan').appendChild(li);
  });
  persist(state);
}

function applyPreset(name){
  const p=presets[name];
  if(!p) return;
  $('action').value=p.action;
  $('situation').value=p.situation;
  $('motionPath').value=p.path;
  $('frameCount').value=String(p.frames);
  $('gridLayout').value=p.grid;
  $('seamlessLoop').checked=p.loop;

  if(name==='rotation'){
    $('subjectType').value='object';
    $('view').value='threequarter';
    $('background').value='transparent';
  }
  if(name==='storyboard'){
    $('background').value='white';
    $('style').value='anime';
    $('view').value='threequarter';
  }
  if(['fly','hover','glide','zeroGravity'].includes(name)){
    $('background').value='sky';
    $('view').value='side';
  }
  if(['swim','treadWater'].includes(name)){
    $('background').value='underwater';
    $('view').value='side';
  }
  if(['standing','sitting','lying','sleep','wake','sitDown','standUp','lieDown','getUp'].includes(name)){
    $('motionMood').value=name==='sleep'?'slow':'natural';
  }
  if(['slide','roll','dodge'].includes(name)) $('motionMood').value='snappy';
  if(name==='dance') $('motionMood').value='dramatic';
  if(name==='interaction') $('motionMood').value='natural';
}

function initHero(){
  const grid=$('heroGrid');
  const poses=[[-12,7,-8,16,-16],[-8,4,-4,18,-12],[-4,2,0,19,-9],[0,0,4,20,-6],[5,-1,8,22,-4],[9,-2,11,24,-2],[12,-2,14,26,0],[14,-1,16,28,1],[12,0,12,26,0],[9,2,9,24,-2],[6,4,6,22,-4],[3,5,3,20,-6],[1,5,1,19,-8],[-2,4,-2,18,-10],[-6,3,-5,17,-12],[-10,6,-7,16,-15]];
  poses.forEach(([x,y,r,fx,fy])=>{
    const c=document.createElement('div');
    c.className='mini-cell';
    c.style.setProperty('--x',`${x}px`);
    c.style.setProperty('--y',`${y}px`);
    c.style.setProperty('--r',`${r}deg`);
    c.style.setProperty('--fx',`${fx}px`);
    c.style.setProperty('--fy',`${fy}px`);
    grid.appendChild(c);
  });
}

function initTheme(){
  const stored=localStorage.getItem('motionPromptLabTheme');
  if(stored==='dark'||stored==='light') document.documentElement.dataset.theme=stored;
  $('themeToggle').addEventListener('click',()=>{
    const next=document.documentElement.dataset.theme==='dark'?'light':'dark';
    document.documentElement.dataset.theme=next;
    localStorage.setItem('motionPromptLabTheme',next);
  });
}

function safeSavedState(){
  try{return normalizeState(JSON.parse(localStorage.getItem('motionPromptLabState')||'null')||{});}
  catch{return {};}
}

initLanguageSelects();
const hashMatch=location.hash.match(/^#s=(.+)$/);
const hashState=hashMatch?decodeState(hashMatch[1]):null;
const initial=normalizeState({...defaults,...safeSavedState(),...(hashState||{})});
$('uiLanguage').value=initial.uiLanguage;
$('promptLanguage').value=initial.promptLanguage;
applyUILanguage(initial.uiLanguage);
applyState(initial);
applyUILanguage(initial.uiLanguage);
applyState(initial);
initHero();
initTheme();
render();

form.addEventListener('input',(e)=>{
  if(e.target.id==='uiLanguage'){
    const state=stateFromForm();
    applyUILanguage(state.uiLanguage);
    applyState(state);
  }
  render();
});

$('preset').addEventListener('change',(e)=>{
  applyPreset(e.target.value);
  render();
});

$('copyBtn').addEventListener('click',async()=>{
  const lang=stateFromForm().uiLanguage;
  try{
    await navigator.clipboard.writeText($('promptOutput').textContent);
    toast(tUI(lang,'copyOk'));
  }catch{
    toast(tUI(lang,'copyFail'));
  }
});

$('shareBtn').addEventListener('click',async()=>{
  const state=stateFromForm();
  const lang=state.uiLanguage;
  const url=new URL(location.href);
  url.hash=`s=${encodeState(state)}`;
  try{
    await navigator.clipboard.writeText(url.toString());
    toast(tUI(lang,'shareOk'));
  }catch{
    location.hash=url.hash;
    toast(tUI(lang,'shareFail'));
  }
});

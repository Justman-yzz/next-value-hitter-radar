// NEXT VALUE — Hitter Radar · 공통 정규화·점수·백테스트 모델 (graph.html, dashboard.html 공용)
// 이 파일에는 선수 데이터가 없다. MLB 시연 데이터는 data/public/(CC BY-SA 3.0)에서, KBO는 사용자가 고른 CSV에서만 온다.
// 리그(MLB/KBO/FUTURES)·시즌별로 따로 계산하며 서로 섞지 않는다. 점수는 탐색용 휴리스틱이며 예측 확률이 아니다.
(function(){
// v2 원석 기준은 KBO 2024–2025 탐색 단계(2026-10-29)에서 정했고, MLB 데이터를 보기 전에 고정했다. 바꾸지 않는다.
const MIN_PA=30, GEM_PA=100, GEM_Z=1.0, GEM_OPS_PCT=45, V1_GEM_SCORE=65, W={power:.45,patience:.30,contact:.25};
// 표본 신뢰도: 지표별 PA/(PA+M). M은 공개 세이버메트릭스 연구에서 흔히 인용되는 안정화 표본 근사값(K% 60, BB% 120, ISO 160)이며 여기서 추정한 값이 아니다.
const STAB={kRate:60,bbRate:120,iso:160};
const num=v=>{if(v===undefined||v===null||String(v).trim()==='')return null;const a=Number(String(v).replaceAll(',','').replace('%',''));return Number.isFinite(a)?a:null};

// 원본 행 → 내부 레코드. 필수값이 없으면 null을 반환하고 임의 대체하지 않는다.
function fromRow(get,sourceFile,allowed){
  const league=String(get('league')??'').trim().toUpperCase(),season=String(get('season')??'').trim();
  const pa=num(get('pa')),bb=num(get('bb')),so=num(get('so')),name=String(get('player_name')??'').trim();
  if(!/^20\d\d$/.test(season)||!allowed.includes(league)||!name||pa===null||pa<=0||bb===null||so===null)return null;
  const n={season,league,id:String(get('player_id')??'').trim(),name,team:String(get('team')??'').trim(),age:num(get('age')),pa,ab:num(get('ab')),h:num(get('h')),bb,so,hbp:num(get('hbp')),avg:num(get('avg')),slg:num(get('slg')),obp:num(get('obp')),hr:num(get('hr')),twoB:num(get('two_b')),threeB:num(get('three_b')),sf:num(get('sf')),g:num(get('g')),pos:String(get('pos')??'').trim(),teamRows:num(get('team_rows'))??1,sourceFile};
  if(n.avg===null&&n.h!==null&&n.ab>0)n.avg=n.h/n.ab;
  if(n.slg===null&&n.h!==null&&n.ab>0&&n.twoB!==null&&n.threeB!==null&&n.hr!==null)n.slg=(n.h+n.twoB+2*n.threeB+3*n.hr)/n.ab;
  // OBP는 공식 정의의 구성요소(H,BB,HBP,AB,SF)가 모두 있을 때만 계산한다. 하나라도 없으면 비워 둔다.
  if(n.obp===null&&n.h!==null&&n.ab!==null&&n.hbp!==null&&n.sf!==null){const d=n.ab+bb+n.hbp+n.sf;if(d>0)n.obp=(n.h+bb+n.hbp)/d}
  n.iso=n.avg!==null&&n.slg!==null?n.slg-n.avg:null;
  n.ops=n.slg!==null&&n.obp!==null?n.slg+n.obp:null;
  n.bbRate=bb/pa;n.kRate=so/pa;
  const bipDen=n.ab!==null&&n.hr!==null&&n.sf!==null?n.ab-so-n.hr+n.sf:null;
  n.babip=bipDen>0&&n.h!==null?(n.h-n.hr)/bipDen:null;
  const rel=k=>pa/(pa+STAB[k]);n.reliability=(rel('kRate')+rel('bbRate')+rel('iso'))/3;
  return n;
}
const ALIASES={season:['season','year','년도','시즌'],league:['league','tier','리그'],player_id:['player_id','playerid','id','선수id'],player_name:['player_name','name','선수명','선수'],team:['team','팀명','팀'],age:['age','나이'],pa:['pa','타석'],ab:['ab','타수'],h:['h','안타'],bb:['bb','walks','볼넷'],so:['so','k','삼진'],hbp:['hbp','hp','사구'],avg:['avg','타율'],slg:['slg','장타율'],obp:['obp','출루율'],hr:['hr','홈런'],two_b:['2b','2루타'],three_b:['3b','3루타'],sf:['sf','희생플라이'],g:['g','경기'],pos:['pos','pos.','포지션'],team_rows:['team_rows']};
function fromObjects(list,sourceFile,allowed=['KBO','FUTURES']){
  const out=[];
  for(const o of list){const lower={};for(const k in o)lower[k.toLowerCase()]=o[k];const get=k=>{for(const a of ALIASES[k]){if(a in lower)return lower[a]}return ''};const n=fromRow(get,sourceFile,allowed);if(n)out.push(n)}
  return out;
}
function csvParse(txt){const out=[];let row=[],value='',quote=false;for(let i=0;i<txt.length;i++){const c=txt[i];if(c==='"'){if(quote&&txt[i+1]==='"'){value+='"';i++}else quote=!quote}else if(c===','&&!quote){row.push(value);value=''}else if((c==='\n'||c==='\r')&&!quote){if(c==='\r'&&txt[i+1]==='\n')i++;row.push(value);if(row.some(x=>x.trim()))out.push(row);row=[];value=''}else value+=c}row.push(value);if(row.some(x=>x.trim()))out.push(row);return out}
// KBO 모드 업로드용: league가 KBO/FUTURES인 행만 받는다 (MLB 행이 섞여 들어오지 않게).
function fromCsv(txt,file,allowed=['KBO','FUTURES']){
  const rows=csvParse(txt);if(rows.length<2)throw Error(file+': 헤더/데이터 행이 없음');
  const hdr=rows[0].map(x=>x.replace(/^﻿/,'').trim().toLowerCase());
  const missing=['season','league','player_name','team','pa','bb','so'].filter(k=>!ALIASES[k].some(a=>hdr.includes(a)));
  if(missing.length)throw Error(file+': 필수 열 누락 '+missing.join(', '));
  const out=fromObjects(rows.slice(1).map(r=>Object.fromEntries(hdr.map((h,i)=>[h,r[i]]))),file,allowed);
  return {rows:out,skipped:rows.length-1-out.length};
}
// MLB 공개 시연 데이터(data/public/mlb_lahman_2023_2025.js)를 읽는다.
function loadMLB(){
  const d=window.NV_MLB;if(!d||!Array.isArray(d.rows))return [];
  return fromObjects(d.rows.map(r=>Object.fromEntries(d.header.map((h,i)=>[h,r[i]]))),'MLB 공개 시연 데이터 (SABR Lahman)',['MLB']);
}
// 여러 파일을 읽을 때 같은 선수-시즌이 두 번 들어오지 않게 한다 (뒤에 읽은 파일 우선).
function dedupe(list){const m=new Map();for(const r of list)m.set(r.season+'|'+r.league+'|'+(r.id||r.name+'|'+r.team),r);return [...m.values()]}

const mean=a=>a.reduce((s,v)=>s+v,0)/a.length;
function corr(x,y){const n=x.length;if(n<3)return null;const mx=mean(x),my=mean(y);let sxy=0,sxx=0,syy=0;for(let i=0;i<n;i++){sxy+=(x[i]-mx)*(y[i]-my);sxx+=(x[i]-mx)**2;syy+=(y[i]-my)**2}return sxx&&syy?sxy/Math.sqrt(sxx*syy):null}
// 백분위: 비교 집단에서 자신보다 작은 값의 비율 (0~100)
function rankPercent(a,v){const s=a.filter(x=>x!==null&&Number.isFinite(x));if(!s.length||v===null)return null;return 100*s.filter(x=>x<v).length/Math.max(1,s.length-1)}

// v1 세부능력 점수(score) → v2 독립 신호(signal).
// v2 = 같은 시즌·리그 집단에서 v1을 OPS 백분위에 선형회귀한 잔차의 표준화 값(z).
// OPS 백분위와의 상관이 0이 되는 것은 회귀 잔차의 수학적 성질일 뿐, 예측력의 근거가 아니다(예측력은 backtest로 따로 확인).
function score(records){
  const groups={};for(const r of records)(groups[r.season+'|'+r.league]??=[]).push(r);
  for(const group of Object.values(groups)){
    const pool=group.filter(x=>x.pa>=MIN_PA&&x.iso!==null&&x.ops!==null);
    const isos=pool.map(x=>x.iso),bbs=pool.map(x=>x.bbRate),ks=pool.map(x=>x.kRate),opss=pool.map(x=>x.ops),ages=pool.filter(x=>x.age!==null).map(x=>x.age);
    for(const r of group){
      r.inPool=pool.includes(r);r.signal=null;r.isGem=false;r.isGemV1=false;r.expScore=null;
      r.agePct=r.age!==null&&ages.length?100-rankPercent(ages,r.age):null; // 높을수록 같은 집단에서 어림
      if(!r.inPool){r.score=null;r.pctOps=null;r.parts=null;continue}
      const p={power:rankPercent(isos,r.iso),patience:rankPercent(bbs,r.bbRate),contact:100-rankPercent(ks,r.kRate)};
      r.parts=p;r.score=p.power*W.power+p.patience*W.patience+p.contact*W.contact;
      r.pctOps=rankPercent(opss,r.ops);r.isGemV1=r.score>=V1_GEM_SCORE&&r.pctOps<GEM_OPS_PCT;
    }
    if(pool.length<10)continue;
    const x=pool.map(r=>r.pctOps),y=pool.map(r=>r.score),mx=mean(x),my=mean(y);
    let sxy=0,sxx=0;for(let i=0;i<pool.length;i++){sxy+=(x[i]-mx)*(y[i]-my);sxx+=(x[i]-mx)**2}
    const b=sxy/sxx,a=my-b*mx,res=pool.map(r=>r.score-(a+b*r.pctOps)),sd=Math.sqrt(res.reduce((s,v)=>s+v*v,0)/(pool.length-2));
    pool.forEach((r,i)=>{r.signal=res[i]/sd;r.expScore=a+b*r.pctOps;r.isGem=r.signal>=GEM_Z&&r.pctOps<GEM_OPS_PCT&&r.pa>=GEM_PA});
  }
  // 직전 시즌 대비 세부 지표 변화 (같은 리그·같은 선수 ID). 설명용이며 원석 판정에는 쓰지 않는다.
  const byKey=new Map();for(const r of records)if(r.id)byKey.set(r.league+'|'+r.id+'|'+r.season,r);
  for(const r of records){const p=r.id?byKey.get(r.league+'|'+r.id+'|'+(+r.season-1)):null;r.prev=p||null;
    r.trend=p&&p.pa>=MIN_PA&&r.pa>=MIN_PA&&p.iso!==null&&r.iso!==null?{iso:r.iso-p.iso,bbRate:r.bbRate-p.bbRate,kRate:r.kRate-p.kRate,ops:r.ops-p.ops,score:r.score!==null&&p.score!==null?r.score-p.score:null}:null}
  return records;
}
const relLabel=v=>v===null||v===undefined?'—':v>=.7?'높음':v>=.5?'보통':'낮음';
function groupStats(records,season,league){
  const pool=records.filter(r=>r.season===season&&r.league===league&&r.inPool);
  const withSig=pool.filter(r=>r.signal!==null);
  return {n:pool.length,rV1:corr(pool.map(r=>r.pctOps),pool.map(r=>r.score)),rV2:corr(withSig.map(r=>r.pctOps),withSig.map(r=>r.signal))};
}

// 재현 가능한 난수 (순열검정용)
function rng(seed){return()=>{seed|=0;seed=seed+0x6D2B79F5|0;let t=Math.imul(seed^seed>>>15,1|seed);t=t+Math.imul(t^t>>>7,61|t)^t;return((t^t>>>14)>>>0)/4294967296}}
function shuffle(a,rand){a=[...a];for(let i=a.length-1;i>0;i--){const j=Math.floor(rand()*(i+1));[a[i],a[j]]=[a[j],a[i]]}return a}
// 최소제곱 결정계수 R² (정규방정식 + 가우스 소거)
function r2(X,y){const n=y.length,k=X[0].length+1,A=Array.from({length:k},()=>Array(k+1).fill(0));
  for(let i=0;i<n;i++){const row=[1,...X[i]];for(let a=0;a<k;a++){for(let b=0;b<k;b++)A[a][b]+=row[a]*row[b];A[a][k]+=row[a]*y[i]}}
  for(let c=0;c<k;c++){let p=c;for(let r=c+1;r<k;r++)if(Math.abs(A[r][c])>Math.abs(A[p][c]))p=r;[A[c],A[p]]=[A[p],A[c]];if(Math.abs(A[c][c])<1e-12)return null;for(let r=0;r<k;r++)if(r!==c){const f=A[r][c]/A[c][c];for(let j=c;j<=k;j++)A[r][j]-=f*A[c][j]}}
  const beta=A.map((r,i)=>r[k]/r[i]),my=mean(y);let ssr=0,sst=0;for(let i=0;i<n;i++){const row=[1,...X[i]];const f=row.reduce((s,v,j)=>s+v*beta[j],0);ssr+=(y[i]-f)**2;sst+=(y[i]-my)**2}return {r2:1-ssr/sst,beta}}

// 백테스트: from 시즌 정보만으로 만든 신호 → to 시즌 OPS 백분위 변화. 두 시즌 모두 GEM_PA 이상, 선수 ID로 연결.
// 예측 변수(OPS 백분위, v1, v2, 나이)는 모두 from 시즌 집단 안에서 계산되므로 to 시즌 정보가 섞이지 않는다.
function backtest(records,from,to,league,iters=5000){
  const idx=s=>{const m=new Map();for(const r of records)if(r.season===s&&r.league===league&&r.inPool&&r.id)m.set(r.id,r);return m};
  const A=idx(from),B=idx(to),pairs=[];
  for(const [id,a] of A){const b=B.get(id);if(b&&a.pa>=GEM_PA&&b.pa>=GEM_PA&&a.signal!==null)pairs.push({a,b,d:b.pctOps-a.pctOps,dOps:b.ops-a.ops})}
  if(pairs.length<10)return {ok:false,pairs:pairs.length};
  const d=pairs.map(p=>p.d),rand=rng(20271),sig=pairs.map(p=>p.a.signal);
  const rSig=corr(sig,d),rV1=corr(pairs.map(p=>p.a.score),d),rOps=corr(pairs.map(p=>p.a.pctOps),d);
  let ge=0;for(let k=0;k<iters;k++){if(corr(shuffle(sig,rand),d)>=rSig)ge++}
  // 추가 설명력: 기준 모형(OPS 백분위 [+ 나이]) 대비 v2 신호를 더했을 때 R² 증가분과 순열 p
  const useAge=pairs.every(p=>p.a.age!==null),baseX=pairs.map(p=>useAge?[p.a.pctOps,p.a.age]:[p.a.pctOps]);
  const base=r2(baseX,d),full=r2(pairs.map((p,i)=>[...baseX[i],sig[i]]),d),dR2=base&&full?full.r2-base.r2:null;
  let ge2=0;if(dR2!==null)for(let k=0;k<iters;k++){const s=shuffle(sig,rand),f=r2(baseX.map((x,i)=>[...x,s[i]]),d);if(f&&f.r2-base.r2>=dR2)ge2++}
  // 후보 선정 방식 비교: OPS 백분위 45 미만(100타석+) 집단 안에서 v2 원석 / v1 원석 / 나머지
  const low=pairs.filter(p=>p.a.pctOps<GEM_OPS_PCT),flag=low.filter(p=>p.a.isGem),rest=low.filter(p=>!p.a.isGem),v1=low.filter(p=>p.a.isGemV1);
  let gp=null,diff=null;
  if(flag.length&&rest.length){diff=mean(flag.map(p=>p.d))-mean(rest.map(p=>p.d));const all=low.map(p=>p.d);let c=0;for(let k=0;k<iters;k++){const s=shuffle(all,rand);if(mean(s.slice(0,flag.length))-mean(s.slice(flag.length))>=diff)c++}gp=c/iters}
  const m=a=>a.length?mean(a.map(p=>p.d)):null,up=a=>a.length?a.filter(p=>p.d>0).length/a.length:null;
  return {ok:true,from,to,league,pairs,n:pairs.length,rSig,rSigP:ge/iters,rV1,rOps,useAge,baseR2:base?.r2??null,fullR2:full?.r2??null,dR2,dR2P:dR2===null?null:ge2/iters,betaSig:full?full.beta[full.beta.length-1]:null,
    low:low.length,lowMean:m(low),lowUp:up(low),flag,flagMean:m(flag),flagUp:up(flag),rest,restMean:m(rest),v1:v1.length,v1Mean:m(v1),diff,diffP:gp,iters};
}

window.NV={MIN_PA,GEM_PA,GEM_Z,GEM_OPS_PCT,V1_GEM_SCORE,W,STAB,fromCsv,fromObjects,loadMLB,dedupe,score,groupStats,backtest,rankPercent,corr,relLabel,
  fmt:(x,d=3)=>x===null||x===undefined||!Number.isFinite(x)?'—':(Math.abs(x)<0.5*10**-d?0:Number(x)).toFixed(d),
  sgn:(x,d=2)=>{if(x===null||x===undefined||!Number.isFinite(x))return '—';if(Math.abs(x)<0.5*10**-d)x=0;return (x>0?'+':'')+x.toFixed(d)},
  pct:x=>x===null||x===undefined?'—':(x*100).toFixed(1)+'%',
  safe:v=>String(v??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]))};
})();

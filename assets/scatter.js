// NEXT VALUE — Hitter Radar · 공통 산점도 렌더러 (graph.html, dashboard.html)
// X = OPS 백분위(0–100), Y = 독립 신호 z(−3~+3, 범위 밖 값은 가장자리에 고정해 표시).
// 원 요소는 선수 1명당 정확히 1개만 그린다(회귀 테스트가 개수를 센다). 선택 표시는 같은 원의 테두리로 한다.
// 범주는 색 + 모양으로 구분: 일반(채움), 원석(채움 + 바깥 링), 소표본 30~99타석(속 빈 원).
(function(){
const NS='http://www.w3.org/2000/svg',Z=3;
function esc(v){return String(v??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]))}
function render(svg,tip,o){
  // 컨테이너 실제 폭으로 그려 글자 크기(px)를 유지한다. 좁은 화면에서는 세로를 늘려 점이 덜 겹치게 한다.
  const cw=Math.round((svg.parentElement&&svg.parentElement.clientWidth)||860),W=o.width||Math.max(300,cw),narrow=W<600;
  const H=o.height||Math.round(narrow?W*1.15:Math.min(560,W*.62)),m=o.margin||(narrow?{l:40,r:10,t:22,b:48}:{l:56,r:20,t:24,b:56});
  const X=v=>m.l+(W-m.l-m.r)*Math.min(100,Math.max(0,v))/100,Y=z=>H-m.b-(H-m.t-m.b)*(Math.max(-Z,Math.min(Z,z))+Z)/(2*Z);
  svg.setAttribute('viewBox',`0 0 ${W} ${H}`);
  const pts=o.points,sel=o.selected;
  let s=`<rect x="${X(0)}" y="${Y(Z)}" width="${X(o.xCut)-X(0)}" height="${Y(o.yCut)-Y(Z)}" fill="#199E70" opacity=".07"/>`;
  for(let v=0;v<=100;v+=20)s+=`<line x1="${X(v)}" x2="${X(v)}" y1="${m.t}" y2="${H-m.b}" stroke="var(--grid)"/><text x="${X(v)}" y="${H-m.b+18}" text-anchor="middle" fill="var(--ink-3)" font-size="12" class="num">${v}</text>`;
  for(let z=-Z;z<=Z;z++)s+=`<line x1="${m.l}" x2="${W-m.r}" y1="${Y(z)}" y2="${Y(z)}" stroke="${z===0?'var(--axis)':'var(--grid)'}"/><text x="${m.l-8}" y="${Y(z)+4}" text-anchor="end" fill="var(--ink-3)" font-size="12" class="num">${z>0?'+':''}${z}</text>`;
  s+=`<line x1="${X(o.xCut)}" x2="${X(o.xCut)}" y1="${m.t}" y2="${H-m.b}" stroke="var(--ink-3)" stroke-dasharray="4 4"/><line x1="${m.l}" x2="${W-m.r}" y1="${Y(o.yCut)}" y2="${Y(o.yCut)}" stroke="var(--ink-3)" stroke-dasharray="4 4"/>`;
  s+=`<text x="${X(1)}" y="${m.t+14}" fill="#3DD6AE" font-size="13" font-weight="700">${esc(o.zoneLabel||'성적에 가려진 신호')}</text>`;
  s+=`<text x="${(m.l+W-m.r)/2}" y="${H-12}" text-anchor="middle" fill="var(--ink-2)" font-size="${narrow?12:13}">${esc(narrow?(o.xLabelShort||o.xLabel):o.xLabel)}</text><text transform="translate(${narrow?12:16} ${(m.t+H-m.b)/2}) rotate(-90)" text-anchor="middle" fill="var(--ink-2)" font-size="${narrow?12:13}">${esc(narrow?(o.yLabelShort||o.yLabel):o.yLabel)}</text>`;
  // 큰 표본을 먼저, 원석·선택을 나중에 그려 위로 올린다
  const order=[...pts].sort((a,b)=>(a===sel)-(b===sel)||(a.isGem-b.isGem)||b.pa-a.pa),coords=[];
  for(const p of order){
    const cx=X(p.pctOps),cy=Y(p.signal),r=Math.max(narrow?2.5:3,Math.min(narrow?6.5:9,(narrow?1.8:2.4)+Math.sqrt(p.pa)/(narrow?4:3))),isSel=p===sel,small=p.pa<100;coords.push([cx,cy,p]);
    let fill,fo,stroke,sw;
    if(p.isGem){fill='var(--series-gem)';fo=.95;stroke='#BFF3E2';sw=1.6}
    else if(small){fill='var(--chart-surface)';fo=.0;stroke='var(--series-small)';sw=1.4}
    else{fill='var(--series-base)';fo=1;stroke='var(--mark-ring)';sw=1}   // 불투명 + 표면색 링: 겹쳐도 점 경계가 보이고 대비 3.36:1 유지
    if(o.dim&&!o.dim(p)&&!isSel){fo*=.25}
    if(isSel){stroke='var(--selected)';sw=2.5}
    s+=`<circle cx="${cx.toFixed(1)}" cy="${cy.toFixed(1)}" r="${(p.isGem?r+1:r).toFixed(1)}" fill="${fill}" fill-opacity="${fo}" stroke="${stroke}" stroke-width="${sw}" stroke-opacity="${o.dim&&!o.dim(p)&&!isSel?.3:1}"><title>${esc(p.name)}</title></circle>`;
  }
  // 직접 라벨: 원석 상위 몇 명 + 선택 선수 (겹치면 생략, 나머지는 툴팁·표로 확인)
  // 기준선 라벨은 점 위에 그려 가려지지 않게 한다
  s+=`<text x="${X(o.xCut)+6}" y="${m.t+12}" fill="var(--ink-2)" font-size="11" paint-order="stroke" stroke="var(--chart-surface)" stroke-width="3">${narrow?'':'OPS 백분위 '}${o.xCut}</text><text x="${W-m.r-4}" y="${Y(o.yCut)-6}" text-anchor="end" fill="var(--ink-2)" font-size="11" paint-order="stroke" stroke="var(--chart-surface)" stroke-width="3">z = +${o.yCut}</text>`;
  if(narrow)o.maxLabels=Math.min(o.maxLabels??6,2);
  const placed=[],lab=(p,bold)=>{let x=X(p.pctOps)+10,y=Y(p.signal)+4,anchor='start';if(x>W-m.r-120){x=X(p.pctOps)-10;anchor='end'}if(!bold&&placed.some(q=>Math.abs(q.y-y)<14&&Math.abs(q.x-x)<120))return;placed.push({x,y});s+=`<text x="${x}" y="${y}" text-anchor="${anchor}" fill="${bold?'var(--ink-1)':'var(--ink-2)'}" font-size="${bold?13:11.5}" font-weight="${bold?700:500}" paint-order="stroke" stroke="var(--chart-surface)" stroke-width="3">${esc(p.name)}</text>`};
  if(sel&&pts.includes(sel))lab(sel,true);
  pts.filter(p=>p.isGem&&p!==sel).sort((a,b)=>b.signal-a.signal).slice(0,o.maxLabels??6).forEach(p=>lab(p,false));
  s+=`<rect class="hit" x="${m.l}" y="${m.t}" width="${W-m.l-m.r}" height="${H-m.t-m.b}" fill="transparent"/>`;
  svg.innerHTML=s;
  // 가장 가까운 점(화면 24px 이내)을 찾는 히트 레이어 — 마우스·터치·펜 공통
  const nearest=e=>{const b=svg.getBoundingClientRect(),k=W/b.width,x=(e.clientX-b.left)*k,y=(e.clientY-b.top)*k;let best=null,bd=(24*k)**2;for(const [cx,cy,p] of coords){const d=(cx-x)**2+(cy-y)**2;if(d<bd){bd=d;best=p}}return best};
  const show=(e,p)=>{if(!tip)return;if(!p){tip.style.opacity=0;return}const box=svg.parentElement.getBoundingClientRect();tip.innerHTML=o.tooltip(p);tip.style.opacity=1;let x=e.clientX-box.left+14,y=e.clientY-box.top+14;if(x+tip.offsetWidth>box.width)x=Math.max(4,e.clientX-box.left-tip.offsetWidth-14);if(y+tip.offsetHeight>box.height)y=e.clientY-box.top-tip.offsetHeight-10;tip.style.left=x+'px';tip.style.top=y+'px'};
  const hit=svg.querySelector('.hit');
  hit.onpointermove=e=>{const p=nearest(e);hit.style.cursor=p?'pointer':'default';show(e,p)};
  hit.onpointerleave=()=>{if(tip)tip.style.opacity=0};
  hit.onclick=e=>{const p=nearest(e);if(p&&o.onSelect)o.onSelect(p)};
  hit.onpointerdown=e=>{if(e.pointerType!=='mouse'){const p=nearest(e);show(e,p)}};
  // 키보드: 차트에 초점을 두고 ←/→ 로 OPS 백분위 순서대로 선수 이동, Esc로 툴팁 닫기
  svg.tabIndex=0;svg.setAttribute('role','img');svg.setAttribute('aria-label',o.aria||'산점도');
  svg.onkeydown=e=>{if(!['ArrowLeft','ArrowRight','Escape'].includes(e.key))return;e.preventDefault();if(e.key==='Escape'){if(tip)tip.style.opacity=0;return}
    const byX=[...pts].sort((a,b)=>a.pctOps-b.pctOps||a.signal-b.signal);let i=byX.indexOf(sel);i=i<0?0:i+(e.key==='ArrowRight'?1:-1);i=Math.max(0,Math.min(byX.length-1,i));if(o.onSelect)o.onSelect(byX[i],{keyboard:true})};
}
// 창 크기가 바뀌면 다시 그리도록 콜백을 등록한다 (폭이 실제로 바뀔 때만, 150ms 디바운스)
function onResize(fn){let w=innerWidth,t;addEventListener('resize',()=>{clearTimeout(t);t=setTimeout(()=>{if(innerWidth!==w){w=innerWidth;fn()}},150)})}
window.NVScatter={render,onResize};
})();

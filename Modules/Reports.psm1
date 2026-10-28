# Raporty HTML z tabel wyników (jak w Domain Ops): samodzielny plik z ciemnym motywem, wyszukiwarką, sortowaniem
# i filtrem pod każdą kolumną, kopiowaniem wiersza lub widocznych wierszy (format Excela), otwieraniem wiersza
# w osobnym oknie i drukiem. Raport nie pobiera niczego z sieci. Moduł nie zależy od interfejsu.
#  - przyciski działają przez atrybut data-act (bez onclick),
#  - filtr kolumny: tekst - zawiera; !tekst - nie zawiera; =tekst - dokładnie; >10, <2026-01-01 - większe/mniejsze.

$script:ReportCss = @'
:root{--bg:#0F1318;--card:#161B22;--card2:#1B212A;--line:#242B36;--line2:#222935;--text:#E4E8EF;--muted:#8791A5;--faint:#5E6779;--ok:#5EE3AE;--warn:#FFC46B;--crit:#FF7A86;--info:#8CC0FF;--accent:#3E6FE0}
*{box-sizing:border-box}body{margin:0;padding:28px 32px;background:var(--bg);color:var(--text);font:13.5px/1.5 "Segoe UI",system-ui,sans-serif}body.popup{padding:20px 22px}a{color:var(--info);text-decoration:none}a:hover{text-decoration:underline}
h1{font-size:24px;margin:0 0 4px}.meta{color:var(--muted);margin-bottom:18px}
.tiles{display:flex;gap:12px;flex-wrap:wrap;margin-bottom:16px}.tile{background:var(--card);border:1px solid var(--line);border-radius:10px;padding:10px 18px;min-width:140px}.tile b{display:block;font-size:22px;font-weight:600}.tile span{color:var(--muted);font-size:12px}
.tile.ok b{color:var(--ok)}.tile.warn b{color:var(--warn)}.tile.crit b{color:var(--crit)}.tile.info b{color:var(--info)}
.bar{position:sticky;top:0;z-index:5;background:var(--card);border:1px solid var(--line);border-radius:10px;padding:10px 12px;margin-bottom:16px;display:flex;gap:10px;align-items:center;flex-wrap:wrap}
input,select{background:var(--card2);color:var(--text);border:1px solid #2A323F;border-radius:7px;padding:7px 10px;font:inherit}.bar input#q{flex:0 1 380px}input[type=checkbox]{width:16px;height:16px;padding:0;margin:0;accent-color:#3E6FE0}
button{background:var(--accent);color:#fff;border:0;border-radius:7px;padding:7px 14px;font:inherit;cursor:pointer}button.g{background:#1E252F;color:#C9D0DC}button:hover{filter:brightness(1.12)}.cnt{color:var(--muted);margin-left:auto}
label.opt{display:inline-flex;align-items:center;gap:7px;color:#C9D0DC;cursor:pointer;white-space:nowrap}
.box{background:var(--card);border:1px solid var(--line);border-radius:12px;margin-bottom:18px;overflow:auto;max-height:80vh}
table{border-collapse:collapse;width:100%}th{background:#1B212A;color:var(--muted);text-align:left;font-weight:600;padding:8px 12px;border-bottom:1px solid var(--line);white-space:nowrap;font-size:12.5px;position:sticky;top:0;z-index:2}
td{padding:6px 12px;border-bottom:1px solid #1F2530;vertical-align:top;white-space:pre-wrap}tr:nth-child(even) td{background:#181E26}
table.dt th.s{cursor:pointer;user-select:none}table.dt th.s:hover{color:var(--text)}table.dt th.asc::after{content:" ▲";color:var(--info)}table.dt th.desc::after{content:" ▼";color:var(--info)}
table.dt tr.fl th{top:35px;padding:4px 6px;background:#181E26}table.dt tr.fl input{width:100%;min-width:70px;padding:3px 7px;font-size:12px;border-radius:5px}
td.ra{white-space:nowrap;width:1%;padding:3px 6px}.ra button,.acts button,.cacts button{background:transparent;color:var(--muted);padding:1px 6px;border-radius:5px;font-size:13px;line-height:1.3}
.ra button:hover,.acts button:hover,.cacts button:hover{background:#2A3342;color:var(--text);filter:none}tbody tr .ra{opacity:.35}tbody tr:hover .ra{opacity:1}
tr.crit td{color:var(--crit)}tr.warn td{color:var(--warn)}tr.muted td{color:#7B8496}
.pill{display:inline-block;padding:2px 11px;border-radius:10px;font-weight:600;font-size:12.5px;white-space:nowrap;background:#1E252F;color:#AEB6C4}.pill.ok{color:var(--ok);background:#15291F}.pill.warn{color:var(--warn);background:#2E2616}.pill.crit{color:var(--crit);background:#2E1A1E}.pill.info{color:var(--info);background:#1A2640}
.chips{margin:10px 0 0}.chip{display:inline-block;font-size:11.5px;padding:1px 9px;border-radius:9px;margin:0 6px 4px 0;background:#1E252F;color:#C9D0DC}.chip.warn{background:#2E2616;color:var(--warn)}.chip.crit{background:#2E1A1E;color:var(--crit)}.chip.info{background:#1A2640;color:var(--info)}
.card{background:var(--card);border:1px solid var(--line);border-radius:12px;padding:18px 20px;margin:0 0 16px;scroll-margin-top:80px}
.head{display:flex;justify-content:space-between;gap:12px;align-items:flex-start}.head h2{margin:0;font-size:18px}.sub{color:var(--muted);margin-top:2px}.top{font-size:12px;color:var(--faint)}.cacts{margin-top:4px}
.grid{display:grid;grid-template-columns:repeat(auto-fill,minmax(340px,1fr));gap:12px;margin-top:14px}.sec{background:var(--card2);border:1px solid var(--line2);border-radius:10px;padding:10px 14px}
.sec h3{margin:0 0 6px;font-size:11px;letter-spacing:.06em;text-transform:uppercase;color:var(--faint)}dl{display:grid;grid-template-columns:minmax(130px,42%) 1fr;gap:3px 12px;margin:0}dt{color:var(--muted)}dd{margin:0;word-break:break-word}dd.e{color:#3F4757}
details{margin-top:12px;border:1px solid var(--line2);border-radius:10px;background:var(--card2);overflow:auto}summary{cursor:pointer;padding:9px 14px;font-weight:600;list-style:none}summary::-webkit-details-marker{display:none}summary::before{content:"▸";display:inline-block;width:16px;color:var(--muted)}details[open]>summary::before{content:"▾";color:var(--info)}
.n{display:inline-block;margin-left:6px;padding:0 8px;border-radius:8px;background:#1A2640;color:var(--info);font-size:11.5px}.empty{padding:2px 14px 12px;color:var(--faint)}.note{padding:6px 14px 10px;color:var(--warn);font-size:12px}
.lf{padding:2px 14px 8px}.lf input{width:260px;padding:4px 8px;font-size:12px}
.tree details{margin:0 0 0 22px;border:0;background:transparent;overflow:visible}.tree details.root{margin:6px 0;background:var(--card);border:1px solid var(--line);border-radius:10px;padding:6px 10px}
.tree summary{padding:3px 4px;border-radius:6px;font-weight:400}.tree summary:hover{background:#1D2430}.leaf{margin-left:38px;padding:2px 4px;color:#AEB6C4;border-radius:6px}.leaf:hover{background:#1D2430}
.acts{display:inline-block;margin-left:8px;opacity:0}summary:hover>.acts,.leaf:hover>.acts{opacity:1}
.k{display:inline-block;font-size:11px;padding:0 7px;border-radius:8px;background:#1A2640;color:#8CC0FF;margin-left:8px}.d{color:#7B8496;font-style:italic;margin-left:8px}.w{color:#FF7A86;margin-left:8px}.m{color:#5E6779}
.hit{background:#2E2616 !important;outline:1px solid #FFC46B}.hide{display:none !important}
.errs{border-color:#4A2A32}.errs h2{color:var(--crit);font-size:15px;margin:0;padding:12px 14px}
#ht-toast{position:fixed;right:20px;bottom:20px;background:#1E2530;border:1px solid #2F3846;color:var(--text);padding:9px 16px;border-radius:9px;opacity:0;transition:opacity .2s;pointer-events:none;z-index:50}#ht-toast.on{opacity:1}
@media print{body{background:#fff;color:#111;padding:0;font-size:11.5px}.bar,.top,.cacts,.acts,.ra,tr.fl,.lf,#ht-toast{display:none !important}.tile,.card,.sec,details,.box{background:#fff !important;border-color:#bbb;max-height:none}.card{break-inside:avoid-page}
th{background:#eee;color:#333;position:static}td{border-color:#ddd}tr:nth-child(even) td{background:#fff}dt,.sub,.meta,.tile span,.sec h3{color:#555}.pill,.chip,.n,.k{border:1px solid #999;background:#fff !important;color:#111 !important}a{color:#111}.tile b{color:#111 !important}.hide{display:none !important}}
'@

$script:ReportJs = @'
(function(){
"use strict";
function T(el){return (el.innerText||el.textContent||"").replace(/ /g," ").trim();}
function esc(s){return String(s).replace(/&/g,"&amp;").replace(/</g,"&lt;").replace(/>/g,"&gt;").replace(/"/g,"&quot;");}
var tt=null;function toast(m){var t=document.getElementById("ht-toast");if(!t)return;t.textContent=m;t.classList.add("on");clearTimeout(tt);tt=setTimeout(function(){t.classList.remove("on")},1800);}
function fallbackCopy(s){var a=document.createElement("textarea");a.value=s;a.style.position="fixed";a.style.top="-1000px";document.body.appendChild(a);a.select();var ok=false;try{ok=document.execCommand("copy")}catch(e){}document.body.removeChild(a);toast(ok?"Skopiowano do schowka":"Nie udało się skopiować");}
function copy(s){if(navigator.clipboard&&window.isSecureContext){navigator.clipboard.writeText(s).then(function(){toast("Skopiowano do schowka")},function(){fallbackCopy(s)})}else{fallbackCopy(s)}}
function openWin(title,html){var w=window.open("","_blank","width=980,height=720,resizable=yes,scrollbars=yes");if(!w){toast("Przeglądarka zablokowała nowe okno – zezwól na wyskakujące okna dla tego pliku");return;}
var css=document.getElementById("ht-css");w.document.open();w.document.write("<!DOCTYPE html><html lang=\"pl\"><head><meta charset=\"utf-8\"><title>"+esc(title)+"</title><style>"+(css?css.textContent:"")+"</style></head><body class=\"popup\">"+html+"</body></html>");w.document.close();}
function clean(el){var c=el.cloneNode(true);c.querySelectorAll(".acts,.cacts,.ra,.lf,tr.fl,.top").forEach(function(x){x.remove()});c.querySelectorAll("details").forEach(function(d){d.open=true});c.querySelectorAll(".hide").forEach(function(x){x.classList.remove("hide")});return c;}
function heads(tbl){var r=tbl.tHead?tbl.tHead.rows[0]:null;if(!r)return[];return Array.prototype.filter.call(r.cells,function(c){return !c.classList.contains("ra")}).map(T);}
function cellsOf(tr){return Array.prototype.filter.call(tr.cells,function(c){return !c.classList.contains("ra")});}
function rowLines(tr){var tbl=tr.closest("table"),h=heads(tbl),c=cellsOf(tr),out=[];for(var i=0;i<c.length;i++){var v=T(c[i]);if(v!=="")out.push((h[i]||("Kolumna "+(i+1)))+": "+v);}return out.join("\n");}
function rowHtml(tr){var tbl=tr.closest("table"),h=heads(tbl),c=cellsOf(tr),s="<h1>"+esc(T(c[0]||tr))+"</h1><div class=\"meta\">"+esc(document.title)+"</div><div class=\"box\"><table>";for(var i=0;i<c.length;i++){s+="<tr><th style=\"position:static\">"+esc(h[i]||"")+"</th><td>"+c[i].innerHTML+"</td></tr>";}return s+"</table></div>";}
function visibleTsv(tbl){var h=heads(tbl),lines=[h.join("\t")];Array.prototype.forEach.call(tbl.tBodies[0].rows,function(tr){if(tr.classList.contains("hide")||tr.style.display==="none")return;lines.push(cellsOf(tr).map(function(c){return T(c).replace(/[\t\r\n]+/g," ")}).join("\t"));});return {text:lines.join("\n"),n:lines.length-1};}
function nodeText(el,depth){var pad=new Array(depth+1).join("  ");if(el.classList&&el.classList.contains("leaf"))return pad+T(el)+"\n";var s=el.querySelector(":scope>summary");var out=pad+(s?T(s):"")+"\n";Array.prototype.forEach.call(el.children,function(ch){if(ch.tagName==="DETAILS"||(ch.classList&&ch.classList.contains("leaf")))out+=nodeText(ch,depth+1);});return out;}
function num(s){var t=String(s).replace(/\s/g,"").replace(",",".");return (t!==""&&!isNaN(t))?parseFloat(t):null;}
function cmp(a,b){var x=num(a),y=num(b);if(x!==null&&y!==null)return x-y;return a.localeCompare(b,"pl",{sensitivity:"base",numeric:true});}
function match(v,f){if(!f)return true;var neg=false;if(f.charAt(0)==="!"){neg=true;f=f.slice(1);if(!f)return true;}var lv=v.toLowerCase(),r;
if(f.charAt(0)==="="){r=lv===f.slice(1).toLowerCase();}else if(f.charAt(0)===">"||f.charAt(0)==="<"){var a=f.slice(1).trim(),x=num(v),y=num(a);var c=(x!==null&&y!==null)?x-y:v.localeCompare(a,"pl",{numeric:true});r=f.charAt(0)===">"?c>0:c<0;if(v==="")r=false;}else{r=lv.indexOf(f.toLowerCase())>=0;}return neg?!r:r;}
function applyTable(tbl){var fr=tbl.tHead.querySelector("tr.fl");var fs=fr?Array.prototype.map.call(fr.querySelectorAll("input"),function(i){return i.value.trim()}):[];var q=tbl.getAttribute("data-q")||"";var n=0,tot=0;
Array.prototype.forEach.call(tbl.tBodies[0].rows,function(tr){tot++;var c=cellsOf(tr),ok=true;for(var i=0;i<fs.length&&ok;i++){if(fs[i]&&!match(T(c[i]||tr),fs[i]))ok=false;}if(ok&&q){ok=T(tr).toLowerCase().indexOf(q)>=0;}tr.classList.toggle("hide",!ok);if(ok)n++;});
var cnt=document.querySelector("[data-count-for=\""+tbl.id+"\"]");if(cnt)cnt.textContent=(n===tot?String(tot):n+" z "+tot);return n;}
function initTable(tbl,i){if(!tbl.id)tbl.id="dt"+i;var h=tbl.tHead?tbl.tHead.rows[0]:null;if(!h||!tbl.tBodies[0])return;var cols=h.cells.length;
Array.prototype.forEach.call(h.cells,function(th,ci){th.classList.add("s");th.title="Kliknij, aby posortować";th.addEventListener("click",function(){var asc=!th.classList.contains("asc");Array.prototype.forEach.call(h.cells,function(x){x.classList.remove("asc","desc")});th.classList.add(asc?"asc":"desc");var rows=Array.prototype.slice.call(tbl.tBodies[0].rows);rows.sort(function(a,b){var r=cmp(T(cellsOf(a)[ci]||a),T(cellsOf(b)[ci]||b));return asc?r:-r;});rows.forEach(function(r){tbl.tBodies[0].appendChild(r)});});});
if(tbl.getAttribute("data-filters")!=="no"){var fr=document.createElement("tr");fr.className="fl";for(var c=0;c<cols;c++){var th=document.createElement("th"),inp=document.createElement("input");inp.placeholder="filtr…";inp.title="Zawiera tekst; !tekst – nie zawiera; =tekst – dokładnie; >10, <2026-01-01 – większe/mniejsze";inp.addEventListener("input",function(){applyTable(tbl)});th.appendChild(inp);fr.appendChild(th);}var e=document.createElement("th");e.className="ra";fr.appendChild(e);tbl.tHead.appendChild(fr);}
var eh=document.createElement("th");eh.className="ra";h.appendChild(eh);
Array.prototype.forEach.call(tbl.tBodies[0].rows,function(tr){var td=document.createElement("td");td.className="ra";td.innerHTML="<button data-act=\"copy-row\" title=\"Kopiuj wiersz\">⧉</button><button data-act=\"open-row\" title=\"Otwórz w osobnym oknie\">↗</button>";tr.appendChild(td);});}
function search(){var q=document.getElementById("q");if(!q)return;var v=q.value.trim().toLowerCase(),mode=q.getAttribute("data-mode")||"cards",n=0;
if(mode==="rows"){document.querySelectorAll("table.dt").forEach(function(t){t.setAttribute("data-q",v);n+=applyTable(t)});}
else if(mode==="tree"){document.querySelectorAll(".hit").forEach(function(e){e.classList.remove("hit")});document.querySelectorAll(".tree details.root").forEach(function(r){var h=!v||T(r).toLowerCase().indexOf(v)>=0;r.classList.toggle("hide",!h);if(h)n++;});if(v){document.querySelectorAll(".tree summary,.tree .leaf").forEach(function(e){var own=e.cloneNode(true);own.querySelectorAll(".acts").forEach(function(x){x.remove()});if(T(own).toLowerCase().indexOf(v)>=0){e.classList.add("hit");var p=e.parentElement;while(p&&p.tagName==="DETAILS"){p.open=true;p=p.parentElement;}}});}}
else{document.querySelectorAll(".card").forEach(function(c){var h=!v||T(c).toLowerCase().indexOf(v)>=0;c.classList.toggle("hide",!h);if(h)n++;var t=document.getElementById("t-"+c.id);if(t)t.classList.toggle("hide",!h);});}
var cnt=document.getElementById("cnt");if(cnt)cnt.textContent=n;}
document.addEventListener("click",function(ev){var b=ev.target.closest("[data-act]");if(!b)return;var a=b.getAttribute("data-act");if(b.closest("summary"))ev.preventDefault();
if(a==="expand"||a==="collapse"){var sel=b.getAttribute("data-sel")||"details";document.querySelectorAll(sel).forEach(function(d){d.open=(a==="expand")});}
else if(a==="print"){window.print();}
else if(a==="copy-row"){copy(rowLines(b.closest("tr")));}
else if(a==="open-row"){var tr=b.closest("tr");openWin(T(cellsOf(tr)[0]||tr),rowHtml(tr));}
else if(a==="copy-card"){copy(T(clean(b.closest(".card"))));}
else if(a==="open-card"){var c=b.closest(".card");var h2=c.querySelector("h2");openWin(h2?T(h2):document.title,clean(c).outerHTML);}
else if(a==="copy-node"){var n=b.closest(".leaf")||b.closest("details");copy(nodeText(n,0).replace(/\s+$/,""));}
else if(a==="open-node"){var d=b.closest("details");var s=d.querySelector(":scope>summary");var c=clean(d);c.open=true;c.classList.add("root");openWin(s?T(clean(s)):document.title,"<div class=\"tree\">"+c.outerHTML+"</div>");}
else if(a==="copy-visible"){var t=document.getElementById(b.getAttribute("data-table"))||document.querySelector("table.dt");if(t){var r=visibleTsv(t);copy(r.text);}}
else if(a==="clear-filters"){document.querySelectorAll("table.dt tr.fl input").forEach(function(i){i.value=""});var q=document.getElementById("q");if(q)q.value="";document.querySelectorAll("table.dt").forEach(function(t){t.setAttribute("data-q","");applyTable(t)});search();}
else if(a==="toggle"){var tg=b.getAttribute("data-class");document.body.classList.toggle(tg,b.checked);}});
document.addEventListener("change",function(ev){var b=ev.target;if(b.getAttribute&&b.getAttribute("data-act")==="toggle"){document.body.classList.toggle(b.getAttribute("data-class"),b.checked);}});
document.querySelectorAll("table.dt").forEach(initTable);
document.querySelectorAll(".lf input").forEach(function(inp){inp.addEventListener("input",function(){var t=document.getElementById(inp.getAttribute("data-table"));if(t){t.setAttribute("data-q",inp.value.trim().toLowerCase());applyTable(t);}})});
var q=document.getElementById("q");if(q)q.addEventListener("input",search);
window.addEventListener("beforeprint",function(){document.querySelectorAll("details").forEach(function(d){d.open=true})});
window.htReport={copy:copy,openWin:openWin,applyTable:applyTable,search:search};
})();
'@


function ConvertTo-HTHtmlText {
    # Tekst do raportu HTML: tylko znaki specjalne (polskie litery zostają czytelne w pliku UTF-8)
    param($Text)
    if ($null -eq $Text -or $Text -is [System.DBNull]) { return '' }
    return ([string]$Text).Replace('&', '&amp;').Replace('<', '&lt;').Replace('>', '&gt;').Replace('"', '&quot;')
}

function Get-HTReportHead {
    # Początek dokumentu: tytuł, wspólne style (+ dodatkowe) i nagłówek z metadanymi
    param([string]$Title, [string]$Meta = '', [string]$ExtraCss = '')
    $sb = New-Object System.Text.StringBuilder
    [void]$sb.Append('<!DOCTYPE html><html lang="pl"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>').Append((ConvertTo-HTHtmlText $Title)).Append('</title><style id="ht-css">')
    [void]$sb.Append($script:ReportCss).Append($ExtraCss).Append('</style></head><body><h1>').Append((ConvertTo-HTHtmlText $Title)).Append('</h1>')
    if ($Meta) { [void]$sb.Append('<div class="meta">').Append((ConvertTo-HTHtmlText $Meta)).Append('</div>') }
    return $sb.ToString()
}

function Get-HTReportBar {
    # Pasek narzędzi: wyszukiwarka (tryb cards / rows / tree) i przyciski
    param([string]$Mode = 'rows', [string]$Placeholder = 'Szukaj…', [string[]]$Buttons = @('copy', 'clear', 'print'), [int]$Count = -1, [string]$Extra = '')
    $labels = @{
        expand   = '<button data-act="expand">Rozwiń listy</button>'
        collapse = '<button class="g" data-act="collapse">Zwiń listy</button>'
        print    = '<button class="g" data-act="print">Drukuj</button>'
        copy     = '<button class="g" data-act="copy-visible" title="Widoczne wiersze w formacie Excela (z nagłówkami)">Kopiuj widoczne</button>'
        clear    = '<button class="g" data-act="clear-filters">Wyczyść filtry</button>'
    }
    $sb = New-Object System.Text.StringBuilder
    [void]$sb.Append('<div class="bar"><input id="q" data-mode="').Append($Mode).Append('" placeholder="').Append((ConvertTo-HTHtmlText $Placeholder)).Append('">')
    foreach ($b in $Buttons) { if ($labels.ContainsKey($b)) { [void]$sb.Append($labels[$b]) } }
    [void]$sb.Append($Extra)
    if ($Count -ge 0) { [void]$sb.Append('<span class="cnt">widoczne: <b id="cnt">').Append($Count).Append('</b></span>') }
    [void]$sb.Append('</div>')
    return $sb.ToString()
}

function Get-HTReportTail {
    return '<div id="ht-toast"></div><script>' + $script:ReportJs + '</script></body></html>'
}

function ConvertTo-HTHtmlReport {
    <#
        Samodzielny raport HTML z tabeli. -Rows: słowniki (kolumna -> wartość); klucz __flag (crit / warn / muted)
        koloruje wiersz. -Tiles: kafelki nad tabelą @{ Label; Value; Tone = ok|warn|crit|info }.
    #>
    param(
        [Parameter(Mandatory)][string]$Title,
        [Parameter(Mandatory)][string[]]$Columns,
        [AllowEmptyCollection()][object[]]$Rows = @(),
        [string]$Meta = '',
        [object[]]$Tiles = @()
    )
    $sb = New-Object System.Text.StringBuilder
    [void]$sb.Append((Get-HTReportHead -Title $Title -Meta $Meta))
    if (@($Tiles).Count) {
        [void]$sb.Append('<div class="tiles">')
        foreach ($t in $Tiles) {
            $tone = if ($t.Tone -in 'ok', 'warn', 'crit', 'info') { " $($t.Tone)" } else { '' }
            [void]$sb.Append("<div class=`"tile$tone`"><b>").Append((ConvertTo-HTHtmlText $t.Value)).Append('</b><span>').Append((ConvertTo-HTHtmlText $t.Label)).Append('</span></div>')
        }
        [void]$sb.Append('</div>')
    }
    [void]$sb.Append((Get-HTReportBar -Mode 'rows' -Placeholder 'Szukaj we wszystkich kolumnach…' -Buttons @('copy', 'clear', 'print') -Extra ('<span class="cnt">wiersze: <b data-count-for="t1">' + @($Rows).Count + '</b></span>')))
    [void]$sb.Append('<div class="box"><table class="dt" id="t1"><thead><tr>')
    foreach ($c in $Columns) { [void]$sb.Append('<th>').Append((ConvertTo-HTHtmlText $c)).Append('</th>') }
    [void]$sb.Append('</tr></thead><tbody>')
    foreach ($r in $Rows) {
        $flag = [string]$r['__flag']
        [void]$sb.Append($(if ($flag -in 'crit', 'warn', 'muted') { "<tr class=`"$flag`">" } else { '<tr>' }))
        foreach ($c in $Columns) { [void]$sb.Append('<td>').Append((ConvertTo-HTHtmlText $r[$c])).Append('</td>') }
        [void]$sb.Append('</tr>')
    }
    [void]$sb.Append('</tbody></table></div>')
    [void]$sb.Append((Get-HTReportTail))
    return $sb.ToString()
}

function ConvertTo-HTUserCardHtml {
    <#
        Wizytówka użytkownika (Microsoft 365 + Exchange + Intune) jako samodzielny plik HTML.
        -Sections: słownik nazwa sekcji -> słownik pole -> wartość (kafelki z listą pól),
        -Tables: @(@{ Title; Columns; Rows = słowniki z opcjonalnym __flag }) - tabele pod kafelkami,
        -Chips: @(@{ Text; Tone = ok|warn|crit|info }) - znaczniki pod nazwą.
    #>
    param(
        [Parameter(Mandatory)][string]$Title,
        [string]$Subtitle = '',
        [System.Collections.IDictionary]$Sections = @{},
        [object[]]$Tables = @(),
        [object[]]$Chips = @(),
        [string]$Meta = ''
    )
    $sb = New-Object System.Text.StringBuilder
    [void]$sb.Append((Get-HTReportHead -Title "Wizytówka: $Title" -Meta $Meta))
    [void]$sb.Append((Get-HTReportBar -Mode 'rows' -Placeholder 'Szukaj w tabelach…' -Buttons @('print')))
    [void]$sb.Append('<div class="card"><div class="head"><div><h2>').Append((ConvertTo-HTHtmlText $Title)).Append('</h2>')
    if ($Subtitle) { [void]$sb.Append('<div class="sub">').Append((ConvertTo-HTHtmlText $Subtitle)).Append('</div>') }
    if (@($Chips).Count) {
        [void]$sb.Append('<div class="chips">')
        foreach ($c in $Chips) {
            $tone = if ($c.Tone -in 'warn', 'crit', 'info') { " $($c.Tone)" } else { '' }
            [void]$sb.Append("<span class=`"chip$tone`">").Append((ConvertTo-HTHtmlText $c.Text)).Append('</span>')
        }
        [void]$sb.Append('</div>')
    }
    [void]$sb.Append('</div></div><div class="grid">')
    foreach ($name in $Sections.Keys) {
        $fields = $Sections[$name]
        if (-not $fields -or $fields.Count -eq 0) { continue }
        [void]$sb.Append('<div class="sec"><h3>').Append((ConvertTo-HTHtmlText $name)).Append('</h3><dl>')
        foreach ($k in $fields.Keys) {
            $v = $fields[$k]
            $text = if ($null -eq $v -or "$v" -eq '') { '' } elseif ($v -is [bool]) { if ($v) { 'Tak' } else { 'Nie' } } elseif ($v -is [System.Collections.IEnumerable] -and $v -isnot [string]) { (@($v) -join "`n") } else { [string]$v }
            [void]$sb.Append('<dt>').Append((ConvertTo-HTHtmlText $k)).Append('</dt>')
            [void]$sb.Append($(if ($text) { '<dd>' } else { '<dd class="e">' })).Append($(if ($text) { ConvertTo-HTHtmlText $text } else { '—' })).Append('</dd>')
        }
        [void]$sb.Append('</dl></div>')
    }
    [void]$sb.Append('</div>')
    $i = 0
    foreach ($t in $Tables) {
        $i++
        $rows = @($t.Rows)
        [void]$sb.Append('<details open><summary>').Append((ConvertTo-HTHtmlText $t.Title)).Append("<span class=`"n`">$($rows.Count)</span></summary>")
        if ($rows.Count -eq 0) { [void]$sb.Append('<div class="empty">brak</div></details>'); continue }
        [void]$sb.Append("<table class=`"dt`" id=`"c$i`"><thead><tr>")
        foreach ($c in $t.Columns) { [void]$sb.Append('<th>').Append((ConvertTo-HTHtmlText $c)).Append('</th>') }
        [void]$sb.Append('</tr></thead><tbody>')
        foreach ($r in $rows) {
            $flag = [string]$r['__flag']
            [void]$sb.Append($(if ($flag -in 'crit', 'warn', 'muted') { "<tr class=`"$flag`">" } else { '<tr>' }))
            foreach ($c in $t.Columns) {
                $v = $r[$c]
                $text = if ($v -is [bool]) { if ($v) { 'Tak' } else { 'Nie' } } else { [string]$v }
                [void]$sb.Append('<td>').Append((ConvertTo-HTHtmlText $text)).Append('</td>')
            }
            [void]$sb.Append('</tr>')
        }
        [void]$sb.Append('</tbody></table></details>')
    }
    [void]$sb.Append('</div>')
    [void]$sb.Append((Get-HTReportTail))
    return $sb.ToString()
}

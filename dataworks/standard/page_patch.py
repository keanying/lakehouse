"""旧版数仓页面专用的模板补丁：在共用模板（dw-dict/src/template.html）上增加「旧系统对照」扩展页签。
只在旧版数仓构建时内存里打补丁，不改 PFT3.0 字典的模板与产物。"""

PAIRS = [
    ("  const T=[['issues','现状问题',LEGACY.findings.length],['map','旧表 → 标准表',LEGACY.mapping.rows.length],...(LEGACY.cover?[['cover','导出模型覆盖',LEGACY.cover.rows.length],['unify','口径统一',LEGACY.unify.rows.length]]:[]),['nodes','旧节点清单',LEGACY.nodes.rows.length]];",
     "  const T=[['issues','现状问题',LEGACY.findings.length],['map','旧表 → 标准表',LEGACY.mapping.rows.length],...(LEGACY.cover?[['cover','导出模型覆盖',LEGACY.cover.rows.length],['unify','口径统一',LEGACY.unify.rows.length]]:[]),['nodes','旧节点清单',LEGACY.nodes.rows.length],...(LEGACY.extra||[]).map(x=>[x.k,x.label,x.rows.length])];\n  const EX=Object.fromEntries((LEGACY.extra||[]).map(x=>[x.k,x]));"),
    ('  v.innerHTML=`<div class="bar" style="margin-bottom:10px"><div class="chips" style="align-items:center">${T.map(([k,l,n])=>`<button class="chip ${tab===k?\'on\':\'\'}" data-k="${k}" style="height:30px;padding:0 14px">${l}<i>${n.toLocaleString?n.toLocaleString():n}</i></button>`).join(\'\')}${qi(LEGACY.tips[tab])}</div><span class="grow"></span>${tab===\'issues\'?`<a class="btn" href="${esc(LEGACY.reportHref)}" style="display:inline-flex;align-items:center;text-decoration:none">问题清单（Markdown）</a>`:\'\'}</div><div id="lh" style="${tab===\'issues\'?\'\':\'flex:1;min-height:0;display:flex;flex-direction:column\'}"></div>`;',
     '  v.innerHTML=`<div class="bar" style="margin-bottom:10px"><div class="chips" style="align-items:center">${T.map(([k,l,n])=>`<button class="chip ${tab===k?\'on\':\'\'}" data-k="${k}" style="height:30px;padding:0 14px">${l}<i>${n.toLocaleString?n.toLocaleString():n}</i></button>`).join(\'\')}${qi(EX[tab]?EX[tab].tip:LEGACY.tips[tab])}</div><span class="grow"></span>${tab===\'issues\'?`<a class="btn" href="${esc(LEGACY.reportHref)}" style="display:inline-flex;align-items:center;text-decoration:none">问题清单（Markdown）</a>`:\'\'}</div><div id="lh" style="${tab===\'issues\'?\'\':\'flex:1;min-height:0;display:flex;flex-direction:column\'}"></div>`;'),
    ("  const D=LEGACY[{map:'mapping',nodes:'nodes',cover:'cover',unify:'unify'}[tab]];const c=D.cols;",
     "  const D=EX[tab]||LEGACY[{map:'mapping',nodes:'nodes',cover:'cover',unify:'unify'}[tab]];const c=D.cols;"),
    ("  grid(h,{state:LS[tab],cols:c,rows:D.rows,wide:true,filters:D.filters,searchPh:{map:'搜索旧表名 / 标准表…',cover:'搜索导出表 / 字段 / 标准指标…',unify:'搜索指标 / 旧口径…',nodes:'搜索节点路径 / 读写表…'}[tab],csvName:tab==='map'?'旧表映射':'旧节点清单',pageSize:200,",
     "  grid(h,{state:LS[tab],cols:c,rows:D.rows,wide:true,filters:D.filters,searchPh:EX[tab]?EX[tab].ph:{map:'搜索旧表名 / 标准表…',cover:'搜索导出表 / 字段 / 标准指标…',unify:'搜索指标 / 旧口径…',nodes:'搜索节点路径 / 读写表…'}[tab],csvName:EX[tab]?EX[tab].label:tab==='map'?'旧表映射':'旧节点清单',pageSize:200,"),
    ('    cell:(i,v,q)=>(c[i]===\'标准表\'||c[i]===\'标准 ADS\')&&v?tlink(v,q):[\'处理\',\'覆盖情况\'].includes(c[i])?`<span class="pill ${AP[v]??\'\'}">${esc(v)}</span>`:/表|路径/.test(c[i])?`<span class="c-id">${hl(esc(v),q)}</span>`:hl(esc(v),q),',
     '    cell:(i,v,q)=>(c[i]===\'标准表\'||c[i]===\'标准 ADS\'||(EX[tab]&&(EX[tab].links||[]).includes(c[i])))&&v&&TBM[v]?tlink(v,q):EX[tab]&&EX[tab].pills&&EX[tab].pills[c[i]]?`<span class="pill ${(Object.entries(EX[tab].pills[c[i]]).find(([k])=>String(v).startsWith(k))||[0,\'\'])[1]}">${esc(v)}</span>`:[\'处理\',\'覆盖情况\'].includes(c[i])?`<span class="pill ${AP[v]??\'\'}">${esc(v)}</span>`:/表|路径/.test(c[i])?`<span class="c-id">${hl(esc(v),q)}</span>`:hl(esc(v),q),'),
    ("      const k=c.indexOf('标准表');if(k>=0&&TBM[r[k]])go('#/tables/'+r[k])}});",
     "      const k=EX[tab]&&EX[tab].links?c.findIndex(n=>EX[tab].links.includes(n)&&TBM[r[c.indexOf(n)]]):c.indexOf('标准表');if(k>=0&&TBM[r[k]])go('#/tables/'+r[k])}});"),
]


def apply(tpl):
    for a, b in PAIRS:
        assert tpl.count(a) == 1, '模板已变更，扩展页签补丁需更新：' + a[:80]
        tpl = tpl.replace(a, b)
    return tpl

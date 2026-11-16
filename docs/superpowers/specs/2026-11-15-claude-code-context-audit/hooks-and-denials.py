import json, os, glob, re, sys, time, collections
home=os.path.expanduser('~')
files=sorted(glob.glob(home+'/.claude/projects/*/*.jsonl'), key=os.path.getmtime, reverse=True)[:50]
now=time.time()
oldest=min(os.path.getmtime(f) for f in files)
projs=collections.Counter(os.path.basename(os.path.dirname(f)) for f in files)
mcp=collections.Counter(); skills=collections.Counter(); cmds=collections.Counter(); agents=collections.Counter()
hooks=collections.defaultdict(list); hook_to=collections.Counter(); hook_err=collections.Counter()
uses={}  # tool_use id -> (name, key)
den=collections.Counter(); denkind=collections.defaultdict(collections.Counter)
SAFE=re.compile(r'^[A-Za-z0-9_.:@/+-]{1,80}$')
def key_for(name, inp):
    if name=='Bash':
        c=(inp or {}).get('command','') if isinstance(inp,dict) else ''
        c=re.sub(r'^\s*(cd\s+\S+\s*&&\s*)?','',c)
        parts=c.split()
        k=' '.join(parts[:2]) if parts else ''
        k=' '.join(p for p in k.split() if SAFE.match(p))
        return 'Bash:'+k
    return name
for f in files:
    try:
        fh=open(f,errors='replace')
    except OSError: continue
    for line in fh:
        try: o=json.loads(line)
        except Exception: continue
        t=o.get('type')
        if t=='assistant':
            for c in (o.get('message',{}).get('content') or []):
                if isinstance(c,dict) and c.get('type')=='tool_use':
                    n=c.get('name','')
                    inp=c.get('input') or {}
                    uses[c.get('id')]=(n,key_for(n,inp))
                    if n.startswith('mcp__'):
                        mcp[n.split('__')[1]]+=1
                    elif n=='Skill':
                        s=str(inp.get('skill',''))
                        if SAFE.match(s): skills[s]+=1
                    elif n in ('Agent','Task'):
                        s=str(inp.get('subagent_type','default'))
                        if SAFE.match(s): agents[s]+=1
        elif t=='user':
            m=o.get('message',{})
            cont=m.get('content')
            txt=cont if isinstance(cont,str) else ' '.join(c.get('text','') for c in cont if isinstance(c,dict) and c.get('type')=='text') if isinstance(cont,list) else ''
            for mm in re.finditer(r'<command-name>/([A-Za-z0-9_:.-]{1,80})</command-name>',txt):
                cmds[mm.group(1)]+=1
            k=o.get('toolDenialKind')
            if k and k not in ('interrupted','cancelled') and isinstance(cont,list):
                for c in cont:
                    if isinstance(c,dict) and c.get('type')=='tool_result':
                        u=uses.get(c.get('tool_use_id'))
                        if u:
                            den[u[1]]+=1; denkind[u[1]][k]+=1
        elif t=='attachment':
            a=o.get('attachment',{})
            at=a.get('type','')
            if at.startswith('hook_'):
                hn=str(a.get('hookName',''))[:60]; ev=str(a.get('hookEvent',''))
                cmd=str(a.get('command',''))
                tail=os.path.basename(cmd.split()[0]) if cmd.split() else ''
                tail=tail if SAFE.match(tail) else '?'
                key=(ev,hn if SAFE.match(hn) else '?',tail)
                d=a.get('durationMs')
                if isinstance(d,(int,float)): hooks[key].append(d)
                if at=='hook_cancelled' and a.get('timedOut'): hook_to[key]+=1
                if at in('hook_non_blocking_error','hook_error_during_execution'): hook_err[key]+=1
print('WINDOW files=%d days=%.1f projects=%d'%(len(files),(now-oldest)/86400,len(projs)))
print('PROJECTS',projs.most_common(8))
print('MCP',mcp.most_common(40))
print('SKILLS',skills.most_common(60))
print('CMDS',cmds.most_common(60))
print('AGENTS',agents.most_common(30))
print('HOOKS')
for k,v in sorted(hooks.items(), key=lambda kv:-sum(kv[1]))[:25]:
    v2=sorted(v); print('  %s n=%d median=%d p90=%d max=%d total_s=%d timeouts=%d errs=%d'%(k,len(v),v2[len(v)//2],v2[int(len(v)*.9)],v2[-1],sum(v)/1000,hook_to[k],hook_err[k]))
print('DENIALS')
for k,n in den.most_common(30): print('  %d %s %s'%(n,k,dict(denkind[k])))

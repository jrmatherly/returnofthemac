import json, os, glob, re, time, collections, subprocess
home=os.path.expanduser('~')
# recursive: subagent transcripts are nested under their session's folder
allf=sorted(glob.glob(home+'/.claude/projects/**/*.jsonl', recursive=True), key=os.path.getmtime, reverse=True)
now=time.time()
files=[f for f in allf if now-os.path.getmtime(f) < 14*86400]
oldest=min(os.path.getmtime(f) for f in files)
SAFE=re.compile(r'^[A-Za-z0-9_.:@/+-]{1,80}$')
mcp=collections.Counter(); skills=collections.Counter(); cmds=collections.Counter(); agents=collections.Counter()
hookout=collections.defaultdict(lambda:[0,0])
for f in files:
    try: fh=open(f,errors='replace')
    except OSError: continue
    for line in fh:
        if '"tool_use"' not in line and 'command-name' not in line and '"hook_' not in line: continue
        try: o=json.loads(line)
        except Exception: continue
        t=o.get('type')
        if t=='assistant':
            for c in (o.get('message',{}).get('content') or []):
                if isinstance(c,dict) and c.get('type')=='tool_use':
                    n=c.get('name',''); inp=c.get('input') or {}
                    if n.startswith('mcp__'): mcp[n.split('__')[1]]+=1
                    elif n=='Skill':
                        s=str(inp.get('skill',''));  skills[s]+= 1 if SAFE.match(s) else 0
                    elif n in('Agent','Task'):
                        s=str(inp.get('subagent_type','default')); agents[s]+= 1 if SAFE.match(s) else 0
        elif t=='user':
            cont=o.get('message',{}).get('content')
            txt=cont if isinstance(cont,str) else ' '.join(c.get('text','') for c in cont if isinstance(c,dict) and c.get('type')=='text') if isinstance(cont,list) else ''
            for mm in re.finditer(r'<command-name>/([A-Za-z0-9_:.-]{1,80})</command-name>',txt): cmds[mm.group(1)]+=1
        elif t=='attachment':
            a=o.get('attachment',{})
            if a.get('type')=='hook_success' or a.get('type')=='hook_additional_context':
                cmd=str(a.get('command','')); tail=os.path.basename(cmd.split()[0]) if cmd.split() else '?'
                tail=tail if SAFE.match(tail) else '?'
                size=sum(len(str(a.get(k,''))) for k in ('stdout','content','additionalContext','output'))
                k=(str(a.get('hookEvent','')),tail); hookout[k][0]+=1; hookout[k][1]+=size
print('WINDOW files=%d days=%.1f'%(len(files),(now-oldest)/86400))
print('MCP',mcp.most_common(40))
print('SKILLS',skills.most_common(80))
print('CMDS',cmds.most_common(80))
print('AGENTS',agents.most_common(40))
print('HOOKOUT (event, cmd): runs, total chars, avg chars')
for k,(n,s) in sorted(hookout.items(), key=lambda kv:-kv[1][1])[:12]: print('  ',k,n,s,s//max(n,1))

import pandas as pd, numpy as np, sys
ed=sys.argv[1]
runs=[pd.read_csv(f"r_{ed}_{g}.csv",index_col=0) for g in ["4x2","6x3","8x3"]]
A=np.stack([r.to_numpy() for r in runs])
idx=runs[0].index; out=np.full(A.shape[1:],np.nan); issues=[]
for i in range(A.shape[1]):
    for j in range(A.shape[2]):
        v=A[:,i,j]; v=v[~np.isnan(v)]
        if len(v)==0:
            if not (ed in ("2015","2016") and i==0): issues.append((idx[i],j+1,"全缺",[]))
            continue
        u=np.unique(np.round(v,1))
        if len(u)==1 and len(v)>=2: out[i,j]=u[0]
        else: issues.append((idx[i],j+1,"冲突" if len(u)>1 else "仅一次",list(np.round(v,1))))
pd.DataFrame(out,index=idx,columns=runs[0].columns).to_csv(f"m_{ed}.csv")
print(ed,"待核格",len(issues))
for s in issues: print("  ",*s)

#!/usr/bin/env python3
"""Compare legacy inventory against generated GeoJSON (read-only)."""
import argparse,csv,collections,json,re
from pathlib import Path
def normalize(title):
    m=re.fullmatch(r"\[\[([^\]|]+)(?:\|[^\]]+)?\]\]",str(title).strip())
    return (m.group(1) if m else str(title)).replace("_"," ").strip()
def read_generated(path):
    data=json.loads(Path(path).read_text(encoding="utf-8"))
    if data.get("type")!="FeatureCollection":raise ValueError("Expected FeatureCollection")
    return data.get("features",[])
def compare(inventory,generated):
    legacy=list(csv.DictReader(open(inventory,encoding="utf-8")))
    current=read_generated(generated)
    old=collections.defaultdict(list);new=collections.defaultdict(list)
    for r in legacy:
        key=("title",normalize(r["wiki_title"]))
        old[key].append(dict(title=normalize(r["wiki_title"]),page_id=str(r["page_id"]) or None,coords=[float(r["longitude"]),float(r["latitude"])]))
    for f in current:
        p=f.get("properties",{});coords=f.get("geometry",{}).get("coordinates",[])
        id_=p.get("page_id",p.get("pageid",p.get("id")))
        title=normalize(p.get("title",""))
        key=("title",title)
        new[key].append(dict(title=title,coords=coords,page_id=str(id_) if id_ is not None else None))
    issues=[]
    for key in sorted(set(old)|set(new)):
        a=old.get(key,[]);b=new.get(key,[])
        if not a:issues.append(dict(kind="added",key=key,generated=b))
        elif not b:issues.append(dict(kind="removed",key=key,legacy=a))
        else:
            if len(a)==1 and len(b)==1 and b[0].get("page_id") and a[0].get("page_id")!=b[0]["page_id"]:issues.append(dict(kind="page_id_changed",key=key,legacy_id=a[0]["page_id"],generated_id=b[0]["page_id"]))
            if len(a)!=len(b):issues.append(dict(kind="multiplicity_changed",key=key,legacy_count=len(a),generated_count=len(b)))
            ao=sorted(json.dumps(i["coords"]) for i in a);bo=sorted(json.dumps(i["coords"]) for i in b)
            if ao!=bo:issues.append(dict(kind="coordinates_changed",key=key,legacy_coords=[i["coords"] for i in a],generated_coords=[i["coords"] for i in b]))
            if sorted(i["title"] for i in a)!=sorted(i["title"] for i in b):issues.append(dict(kind="titles_changed",key=key,legacy_titles=[i["title"] for i in a],generated_titles=[i["title"] for i in b]))
    return {"legacy_count":len(legacy),"generated_count":len(current),"issues":issues,"issue_count":len(issues)}
if __name__=="__main__":
    ap=argparse.ArgumentParser()
    ap.add_argument("--inventory",default="geo-initiative/migration/reports/inventory.csv")
    ap.add_argument("--generated",required=True)
    ap.add_argument("--output",default="geo-initiative/migration/reports/comparison.json")
    args=ap.parse_args()
    result=compare(args.inventory,args.generated)
    Path(args.output).write_text(json.dumps(result,ensure_ascii=False,indent=2)+"\n",encoding="utf-8")
    print(json.dumps({"legacy_count":result["legacy_count"],"generated_count":result["generated_count"],"issue_count":result["issue_count"]},ensure_ascii=False))
    raise SystemExit(0 if result["issue_count"]==0 else 1)


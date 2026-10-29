#!/usr/bin/env python3
"""Read-only MediaWiki API inventory of the legacy map."""
import argparse, collections, csv, hashlib, json, re, urllib.parse, urllib.request
from pathlib import Path

API = "https://mapamovsaude.net.br/api.php"
def request(params):
    data = urllib.parse.urlencode(dict(action="query", format="json", formatversion=2, **params)).encode()
    req = urllib.request.Request(API + "?" + data.decode(), headers={"User-Agent":"MapaGeoMigrationAudit/0.1 (editorial inventory)"})
    with urllib.request.urlopen(req, timeout=40) as response:
        return json.load(response)

def extract(text):
    m = re.search(r"<mapframe\b[^>]*>(.*?)</mapframe>", text, flags=re.I|re.S)
    if not m: raise ValueError("mapframe missing")
    value=json.loads(re.sub(r"(?m)(\s+)//[^\n]*$", "", m.group(1)).strip())
    if value.get("type") != "FeatureCollection": raise ValueError("not a FeatureCollection")
    return value

def title_of(value):
    m=re.fullmatch(r"\[\[([^\]|]+)(?:\|[^\]]+)?\]\]", value.strip())
    return m.group(1).replace("_"," ") if m else None

def audit(out):
    out.mkdir(parents=True, exist_ok=True)
    result=request({"prop":"revisions", "rvprop":"ids|timestamp|content", "rvslots":"main", "titles":"Predefinição:Mapa Brasil"})
    page=result["query"]["pages"][0]
    rev=page["revisions"][0]
    if rev["revid"] != 2576: raise RuntimeError(f"Live revision changed: {rev['revid']} (expected 2576)")
    raw=rev["slots"]["main"]["content"]
    geo=extract(raw)
    features=geo["features"]
    if len(features)!=82: raise RuntimeError(f"Expected 82, got {len(features)}")
    (out/"legacy.geojson").write_text(json.dumps(geo,ensure_ascii=False,indent=2)+"\n",encoding="utf-8")
    titles=[title_of(f.get("properties",{}).get("title","")) for f in features]
    lookup={}
    unique=sorted(set(t for t in titles if t))
    for start in range(0,len(unique),40):
        resp=request({"titles":"|".join(unique[start:start+40]),"redirects":"1","prop":"info"})
        q=resp["query"]
        normalized={n["from"]:n["to"] for n in q.get("normalized",[])}
        redirects={n["from"]:n["to"] for n in q.get("redirects",[])}
        by_title={p["title"]:p for p in q["pages"]}
        for original in unique[start:start+40]:
            name=normalized.get(original,original)
            dest=redirects.get(name,name)
            lookup[original]=(by_title.get(dest,{}),dest,name!=dest)
    counts=collections.Counter(t for t in titles if t)
    coords=collections.Counter(tuple(f.get("geometry",{}).get("coordinates",[])) for f in features)
    rows=[]
    for i,(f,title) in enumerate(zip(features,titles),1):
        point=f.get("geometry",{})
        xy=point.get("coordinates",[])
        longitude,latitude=(xy+[None,None])[:2] if isinstance(xy,list) else (None,None)
        pg,dest,redirect=lookup.get(title,({},"",False))
        flags=[]
        if title is None: flags.append("invalid_title")
        if pg.get("missing"): flags.append("missing_page")
        if redirect: flags.append("redirect")
        if title and counts[title]>1: flags.append("duplicate_title")
        if len(xy)!=2 or not all(isinstance(x,(int,float)) and not isinstance(x,bool) for x in xy) or not (-180<=longitude<=180 and -90<=latitude<=90): flags.append("invalid_coordinate")
        if len(xy)==2 and coords[tuple(xy)]>1: flags.append("shared_coordinates_review")
        if title and dest and title.replace("_"," ")!=dest: flags.append("resolved_title_differs")
        if title and "Loucure-se" in title and [longitude,latitude]!=[-40.3512,-3.68274]: flags.append("LOUCURE_SE_COORDINATE_REGRESSION")
        rows.append(dict(index=i,legacy_title=f.get("properties",{}).get("title",""),wiki_title=title or "",resolved_title=dest,page_id=pg.get("pageid",""),longitude=longitude,latitude=latitude,properties=json.dumps(f.get("properties",{}),ensure_ascii=False,sort_keys=True),geo_role="unknown",evidence="legacy_revision_2576",review="editorial_review" if flags else "technical_candidate",flags=";".join(flags)))
    cols=list(rows[0])
    with (out/"inventory.csv").open("w",newline="",encoding="utf-8") as fd:
        writer=csv.DictWriter(fd,fieldnames=cols);writer.writeheader();writer.writerows(rows)
    with (out/"editorial-review.csv").open("w",newline="",encoding="utf-8") as fd:
        writer=csv.DictWriter(fd,fieldnames=cols);writer.writeheader();writer.writerows(r for r in rows if r["flags"])
    flagged=collections.Counter(flag for r in rows for flag in r["flags"].split(";") if flag)
    report={"source_page_id":page["pageid"],"revision_id":rev["revid"],"revision_timestamp":rev["timestamp"],"wikitext_sha256":hashlib.sha256(raw.encode()).hexdigest(),"total":len(rows),"technical_candidates":sum(not r["flags"] for r in rows),"editorial_review":sum(bool(r["flags"]) for r in rows),"flags":dict(flagged),"unknown_geo_role":len(rows),"notes":["Technical candidate does not mean that the coordinates or geographic role have been editorially confirmed.","All 82 require editorial role decision before publishing role information."]}
    (out/"quality.json").write_text(json.dumps(report,ensure_ascii=False,indent=2)+"\n",encoding="utf-8")
    print(json.dumps(report,ensure_ascii=False,indent=2))
if __name__=="__main__":
    ap=argparse.ArgumentParser();ap.add_argument("--output",default="geo-initiative/migration/reports");args=ap.parse_args()
    audit(Path(args.output))


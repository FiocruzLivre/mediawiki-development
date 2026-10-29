#!/usr/bin/env python3
"""Strictly read-only migration proposal. Never writes MediaWiki pages."""
import argparse,csv,json,urllib.parse,urllib.request,re,hashlib
from pathlib import Path
API="https://mapamovsaude.net.br/api.php"
TEMPLATE="Geolocalização do artigo"
def query(params):
    req=urllib.request.Request(API+"?"+urllib.parse.urlencode(dict(action="query",format="json",formatversion=2,**params)),headers={"User-Agent":"MapaGeoMigrationAudit/0.1"})
    with urllib.request.urlopen(req,timeout=40) as fd:return json.load(fd)
def plan(inventory,output):
    rows=list(csv.DictReader(open(inventory,encoding="utf-8")))
    eligible=[r for r in rows if r["review"]=="technical_candidate" and r["page_id"]]
    pages={}
    ids=sorted(set(r["page_id"] for r in eligible),key=int)
    for i in range(0,len(ids),40):
        result=query({"pageids":"|".join(ids[i:i+40]),"prop":"revisions|info","rvprop":"ids|timestamp|content","rvslots":"main"})
        pages.update({str(p["pageid"]):p for p in result["query"]["pages"]})
    changes=[]
    for row in rows:
        proposal={"index":row["index"],"title":row["wiki_title"],"page_id":row["page_id"],"status":"blocked_review" if row["flags"] else "candidate","flags":row["flags"],"legacy_lon":row["longitude"],"legacy_lat":row["latitude"]}
        if proposal["status"]=="candidate":
            p=pages.get(row["page_id"])
            if not p or not p.get("revisions"):proposal["status"]="blocked_missing_revision"
            else:
                rev=p["revisions"][0];source=rev["slots"]["main"]["content"]
                proposal.update(baserevid=rev["revid"],basetimestamp=rev["timestamp"],source_sha256=hashlib.sha256(source.encode()).hexdigest())
                # Fail closed on any existing geographic information, including GeoData coordinates.
                if re.search(r"\{\{\s*(?:Geolocaliza(?:ç|c)[aã]o[_ ]do[_ ]artigo|#coordinates|Coord(?:enadas)?)\b|\b(?:latitude|longitude)\s*=",source,re.I):
                    proposal["status"]="blocked_existing_geolocation"
                else:
                    proposed=f"{{{{{TEMPLATE}|latitude={row['latitude']}|longitude={row['longitude']}}}}}"
                    proposal["proposed_append"]=proposed
                    proposal["status"]="proposed_dry_run"
        changes.append(proposal)
    output.parent.mkdir(parents=True,exist_ok=True)
    output.write_text(json.dumps({"mode":"dry-run-only","schema_unapproved":True,"source_revision":2576,"proposals":changes},ensure_ascii=False,indent=2)+"\n",encoding="utf-8")
    print(json.dumps({"mode":"dry-run-only","total":len(changes),"statuses":{k:sum(x["status"]==k for x in changes) for k in sorted(set(x["status"] for x in changes))}},ensure_ascii=False,indent=2))
if __name__=="__main__":
    parser=argparse.ArgumentParser()
    parser.add_argument("--dry-run",action="store_true",required=True,help="Mandatory: generation of proposals only, no editing")
    parser.add_argument("--inventory",default="geo-initiative/migration/reports/inventory.csv")
    parser.add_argument("--output",default="geo-initiative/migration/reports/proposals.json")
    args=parser.parse_args()
    if not args.dry_run:parser.error("--dry-run is required")
    plan(args.inventory,Path(args.output))


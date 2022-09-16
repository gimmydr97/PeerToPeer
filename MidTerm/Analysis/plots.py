import pandas as pd
import plotly.express as px
import functools
from ipstack import GeoLookup


IP_STACK_KEY = "ac00140885a5dca0d8277d8e946d227c"

geo_lookup = GeoLookup(IP_STACK_KEY)

#return the location of an ip
@functools.lru_cache(maxsize=2048)
def lookup(host):
    location = geo_lookup.get_location(host)
    return location


log = pd.read_csv('logPeers2.csv', delimiter = ';', header = 0)

#pie plot for received byte for cooperating partners
totB = log['Byte_received'].sum()
percentuali =[]
peers = []
other = 0
i=0
for elem in log['Byte_received'] :
    p = elem/totB
    if p*100 > 2 :
        percentuali.append(p)
        peers.append(log.iloc[i,1])
    else : other = other + p
    i=i+1

percentuali.append(other)
peers.append("other")

percentuali = pd.DataFrame(percentuali,columns = ['percentuali'])
peers = pd.DataFrame(peers,columns = ['peers'])
perc_peers = pd.concat([percentuali,peers], axis = 1)

br_pie = px.pie(perc_peers, values="percentuali", names='peers')
br_pie.show()

# % of peers in the bitswap agent list that cooperated
logPartners = pd.read_csv('logBA2.csv', header = 0)
percentuali = []
label = []
pc = len(log['IP']) * 100 / len(logPartners['CID'])
percentuali.append(pc)
percentuali.append(100-pc)
label.append("cooperating peers")
label.append("other peers in the bitswap agent list")

percentuali = pd.DataFrame(percentuali,columns = ['percentuali'])
label = pd.DataFrame(label,columns = ['label'])
perc_peers_coop = pd.concat([percentuali,label], axis = 1)

perc_coop_pie = px.pie(perc_peers_coop, values="percentuali", names='label')
perc_coop_pie.show()

# pie plot on multihash type useed by CID of partners 
identity = 0
sha = 0
for elem in logPartners['CID'] :
    
    if elem[0] == "Q" :
        sha = sha + 1
    else : identity = identity + 1

d = {'presenza':  [sha,identity],
     'multihash': ['sha2-256', 'identity' ]}
multihash_df = pd.DataFrame(data=d) 
multihas_pie = px.pie(multihash_df, values='presenza', names='multihash')
multihas_pie.show()

# geolocation
countries =[]

for elem in log['IP']:
    location = lookup(elem)
    countries.append(location['country_name'] if location else "Unknown")
    
countries = pd.DataFrame(countries,columns = ['countries'])
ndf = pd.concat([log,countries], axis = 1)

regions = ndf.groupby(['countries'], as_index=False).count()
countries_scatter = px.scatter_geo(regions,
                               locationmode='country names', locations="countries", size_max=30,
                               hover_name="countries", hover_data=['CID'], size="CID", color="countries",
                               width=1200, height=600)
countries_scatter.show()

# pie plot with percentages of the countries of cooperating peers 
countries_pie = px.pie(regions, values="CID", names='countries')
countries_pie.show()







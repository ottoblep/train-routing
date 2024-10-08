import plotly.graph_objects as go
import networkx as nx
import numpy as np 
import matplotlib.pyplot as plt

network = np.genfromtxt('network.csv', delimiter=',')
traj_edges = np.genfromtxt('trajectories_edges.csv', delimiter=',')
traj_positions = np.genfromtxt('trajectories_positions.csv', delimiter=',')

G = nx.from_numpy_array(network)
pos=nx.fruchterman_reingold_layout(G)

edge_x = []
edge_y = []
for count, edge in enumerate(G.edges()):
    x0, y0 = pos[edge[0]]
    x1, y1 = pos[edge[1]]
    edge_x.append(x0)
    edge_x.append(x1)
    edge_x.append(None)
    edge_y.append(y0)
    edge_y.append(y1)
    edge_y.append(None)

edge_trace = go.Scatter(
    x=edge_x, y=edge_y,
    line=dict(width=1, color='black'),
    hoverinfo='none',
    mode='lines')

node_x = []
node_y = []
n_nodes = len(G.nodes())
for node in G.nodes():
    x, y = pos[node]
    node_x.append(x)
    node_y.append(y)

node_trace = go.Scatter(
    x=node_x, y=node_y,
    mode='markers+text',
    textposition="top center",
    text=[str(x) for x in range(1,n_nodes+1)],
    marker=dict(
        size=3,
        color='black',
        line_width=2)
)

train_traces = []
n_slider_steps = 200
max_timestep = np.shape(traj_edges)[1]
# Edges are saved by their nonzero order in the adjacency matrix 
edge_nodes_1, edge_nodes_2 = np.nonzero(np.transpose(network))
for timestep in range(0, max_timestep, int(np.floor(max_timestep/n_slider_steps))):
    train_x = []
    train_y = []
    for train in range(np.shape(traj_edges)[0]):
        edge = traj_edges[train, timestep]
        position = 1 - traj_positions[train, timestep]
        pos_node_1 = pos[edge_nodes_1[int(edge-1)]] 
        pos_node_2 = pos[edge_nodes_2[int(edge-1)]]
        x = pos_node_1[0] + position * (pos_node_2[0] - pos_node_1[0])
        y = pos_node_1[1] + position * (pos_node_2[1] - pos_node_1[1])
        train_x.append(x)
        train_y.append(y)

    train_traces.append(go.Scatter(
        x=train_x, y=train_y,
        visible=False,
        mode='markers+text',
        textposition="top center",
        text=[str(x) for x in range(1,np.shape(traj_edges)[0]+1)],
        marker=dict(
            color=list(range(np.shape(traj_edges)[0])),
            colorscale="rainbow",
            size=10,
            line_width=2)
    ))

# Create and add slider
steps = []
n_steps = len(train_traces) + 2
for i in range(2,n_steps):
    visibility = [False] * n_steps
    visibility[i] = True
    visibility[0] = True
    visibility[1] = True
    step = dict(
        method="update",
        args=[{"visible": visibility}],
        label=str((i-2) * np.floor(max_timestep/n_slider_steps))
    )
    steps.append(step)

sliders = [dict(
    active=0,
    currentvalue={"prefix": "Timestep: "},
    pad={"t": 50},
    steps=steps
)]

fig = go.Figure(data=[edge_trace, node_trace] + train_traces,
             layout=go.Layout(
                title='Train Network',
                titlefont_size=16,
                showlegend=False,
                hovermode='closest',
                uirevision = True,
                margin=dict(b=20,l=5,r=5,t=40),
                sliders=sliders,
                xaxis=dict(showgrid=False, zeroline=False, showticklabels=False),
                yaxis=dict(showgrid=False, zeroline=False, showticklabels=False))
                )

# Make initial timestep visible
fig.data[2].visible = True

fig.show()
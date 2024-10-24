%% Max Multicommodity Network Flow algorithm from "Approximating fractional multicommodity flow independent of the number of commodities" (Fleischer 2000)
% This implementation is adapted to a directed graph without loops and and and identical number of source and sink nodes
function [flow_value, edge_flows] = maxMulticommodityFlowApprox(network, network_digraph, n_source_sink_nodes, demand_matrix, e_accuracy)
     % network is the directed adjacency matrix with format (sources, other, sinks)
     % e_accuracy is the epsilon in (1+epsilon)

     k_demand_pairs = n_source_sink_nodes^2 - n_source_sink_nodes;

     % We add helper nodes to conform to limit flow for each source-sink-pair according to the demand matrix
     % This adds n_source_sink_nodes^2 - n_source_sink_nodes nodes to the network with each one edge that has capacity demand_i,j

     %         | demand_helpers              | sources| routes|  sinks|
     % helpers |                             |D12     |       |       |
     %         |                             |D13     |       |       |
     %         |             0               |   D21  |       |       |
     %         |                             |   D23  |   0   |   0   |
     %         |                             |     D31|       |       |
     %         |                             |     D32|       |       |
     % sources |                             |   0    |   A   |   I   |
     % routes  |             0               |   0    |   B   |   C   |
     % sinks   |                             |   0    |   0   |   0   |

     % demands is the serialized row-order upper triangular of a n_source_sink_nodes^2 demand matrix
     demand_matrix_transposed = transpose(demand_matrix);
     demands = demand_matrix_transposed(~eye(size(demand_matrix)));

     % Insert transfer graph (A,B,C,I)  
     n_helper_nodes = k_demand_pairs;
     network_full = sparse(size(network,1) + n_helper_nodes, size(network,1) + n_helper_nodes);
     network_full(n_helper_nodes + 1:n_helper_nodes + size(network,1), n_helper_nodes + 1:n_helper_nodes + size(network,1)) = network;
     
     % Add demand helpers (D12, D13 etc)
     for i_source_node = 1:n_source_sink_nodes
        helpers_base_idx = (i_source_node-1) * (n_source_sink_nodes - 1);
        for j_sink_node = 1:(n_source_sink_nodes - 1)
          network_full(helpers_base_idx + j_sink_node, n_helper_nodes + i_source_node) = demands(helpers_base_idx + j_sink_node);
        end
     end
     network_full_digraph = digraph(network_full);

     [~, ~, edge_capacities] = find(network_full);
     n_nodes = size(network_full,1);
     m_edges = numel(edge_capacities);
     
     demand_pair_idxs = combinations(1:n_source_sink_nodes, n_nodes-n_source_sink_nodes+1:n_nodes);
     % Remove diagonal
     demand_pair_idxs = demand_pair_idxs{demand_pair_idxs{:,1}~=demand_pair_idxs{:,2} - (n_nodes-n_source_sink_nodes),:};

     demand_paths = cell(k_demand_pairs, 1);
     for i_demand_pair = 1:k_demand_pairs
          [~, demand_paths{i_demand_pair}] = allpaths(network_full_digraph, demand_pair_idxs(i_demand_pair, 1), demand_pair_idxs(i_demand_pair, 2));
     end
     n_demand_path_sizes = cellfun('size', demand_paths, 1);
     n_demand_paths = sum(n_demand_path_sizes);

     % L maximum number of arcs in augmenting path
     L = max(n_demand_path_sizes);

     % delta is initial dual problem path length
     delta = (1 + e_accuracy) / ((1 + e_accuracy) * L)^(1/e_accuracy);

     % Initialize decision vars for primal and dual problem
     x = zeros(1, n_demand_paths);
     l = ones(1, m_edges) * delta;

     n_phases = 0;
     for i = 1:log(((1+e_accuracy)/delta)) / log(1+e_accuracy)
          n_phases = n_phases + 1;
          for j = 1:k_demand_pairs
               relevant_paths = demand_paths{j};
               [P_idx, P_len] = weightedShortestPath(relevant_paths, l);
               if P_idx == 0
                    continue;
               end
               P = relevant_paths{P_idx,1};

               while P_len < min([1 delta*(1+e_accuracy)^i])
                    demand_to_assign_u = min(edge_capacities(P));

                    global_path_idx = P_idx + sum(n_demand_path_sizes(1:j-1));
                    x(global_path_idx) = x(global_path_idx) + demand_to_assign_u;

                    for i_path_edge = 1:numel(P)
                         global_edge_idx = P(i_path_edge);
                         l(global_edge_idx) = l(global_edge_idx) * (1 + (demand_to_assign_u * e_accuracy) / edge_capacities(global_edge_idx));
                    end

                    [P_idx, P_len] = weightedShortestPath(relevant_paths, l);
                    P = relevant_paths{P_idx,1};
               end
          end
     end

     % Scale result
     result = x / (log(1 / delta) / log(1 + e_accuracy));
     flow_value = sum(result);

     % Sum edge flows
     edge_flows = zeros(m_edges, 1);
     for j_demand_pair = 1:k_demand_pairs
          paths = demand_paths{j_demand_pair};
          if isempty(paths)
               continue
          end
          for i_path = 1:numel(paths)
               P = paths{i_path,1};
               global_path_idx = i_path + sum(n_demand_path_sizes(1:j_demand_pair-1));
               for i_path_edge = 1:numel(P)
                    global_edge_idx = P(i_path_edge);
                    edge_flows(global_edge_idx) = edge_flows(global_edge_idx) + result(global_path_idx);
               end
          end
     end
end

function [shortest_path_idx best_length] = weightedShortestPath(paths, edge_weights)
     best_length = Inf;
     shortest_path_idx = 0;
     if isempty(paths)
          shortest_path_idx = 0;
     end
     for i_path = 1:numel(paths)
          path = paths{i_path,1};
          length = 0;
          for j_edge_in_path = 1:size(path,2)
               length = length + edge_weights(path(j_edge_in_path));
          end
          if length < best_length
               best_length = length;
               shortest_path_idx = i_path;
          end
     end
end
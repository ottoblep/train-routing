%% Max-concurrent Multicommodity Network Flow algorithm from "Approximating fractional multicommodity flow independent of the number of commodities" (Fleischer 2000)
% This implementation is adapted to a directed graph without loops and and and identical number of source and sink nodes
function [flow_value, edge_flows] = maxMulticommodityFlowApprox(network, network_digraph, n_source_sink_nodes, demand_matrix, e_accuracy)
     % network is the directed adjacency matrix
     % e_accuracy is the epsilon in (1+epsilon)

     % demands is the serialized row-order upper triangular of a n_source_sink_nodes^2 demand matrix
     demands = demand_matrix(~eye(size(demand_matrix)));

     [~, ~, edge_capacities] = find(network);
     n_nodes = size(network,1);
     m_edges = numel(edge_capacities);
     k_demand_pairs = n_source_sink_nodes^2 - n_source_sink_nodes;
     demand_pair_idxs = combinations(1:n_source_sink_nodes, n_nodes-n_source_sink_nodes+1:n_nodes);
     % Remove diagonal
     demand_pair_idxs = demand_pair_idxs{demand_pair_idxs{:,1}~=demand_pair_idxs{:,2} - (n_nodes-n_source_sink_nodes),:};

     demand_paths = cell(k_demand_pairs, 1);
     for i_demand_pair = 1:k_demand_pairs
          [~, demand_paths{i_demand_pair}] = allpaths(network_digraph, demand_pair_idxs(i_demand_pair, 1), demand_pair_idxs(i_demand_pair, 2));
     end
     n_demand_path_sizes = cellfun('size', demand_paths, 1);
     n_demand_paths = sum(n_demand_path_sizes);

     % delta is initial dual problem path length
     delta = (m_edges / (1 - e_accuracy))^(-1/e_accuracy);
     
     % Initialize decision vars for primal and dual problem
     x = zeros(1, n_demand_paths);
     l = delta ./ edge_capacities;
     
     % Dual objective function D(l) = sum(u(e)l(e))
     D_l = @(l_arg) sum(edge_capacities.*l_arg');
     demand_remaining = zeros(1,k_demand_pairs);
     
     while D_l(l) < 1
          for j = 1:k_demand_pairs
               demand_remaining(j) = demands(j);
               while D_l(l) < 1 & demand_remaining(j) > 0
                    % Shortest path in P_j using l
                    relevant_paths = demand_paths{j};
                    P_idx = weightedShortestPath(relevant_paths, l);
                    if P_idx == 0
                         break;
                    end
                    P = relevant_paths{P_idx,1};
               
                    smallest_capacity_in_p = min(edge_capacities(P));
                    demand_to_assign_u = min([demand_remaining(j) smallest_capacity_in_p]);
               
                    demand_remaining(j) = demand_remaining(j) - demand_to_assign_u;
               
                    global_path_idx = P_idx + sum(n_demand_path_sizes(1:j-1));
               
                    % Assign demand
                    x(global_path_idx) = x(global_path_idx) + demand_to_assign_u;
               
                    for i_path_edge = 1:numel(P)
                         global_edge_idx = P(i_path_edge);
                         l(global_edge_idx) = l(global_edge_idx) * (1 + (demand_to_assign_u * e_accuracy) / edge_capacities(global_edge_idx));
                    end
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

function shortest_path_idx = weightedShortestPath(paths, edge_weights)
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
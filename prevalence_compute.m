function prevalence(a, P2, alpha)
if nargin == 0, test_prevalence, return, end


% permutation-based prevalence inference
%
% gamma0max = prevalence(inputfilenames, P2 = 1e6, outputfilename = 'prevalence', alpha = 0.05)
%
% inputfilenames:   cell array of input image filenames, subjects x permutations
% P2:               number of second-level permutations to perform
% outputfilename:   output image filename
% alpha:            significance level
% gamma0max:        theoretical upper bound on gamma0
%
%
% Copyright (C) 2016 Carsten Allefeld
%
% This program is free software: you can redistribute it and/or modify it
% under the terms of the GNU General Public License as published by the
% Free Software Foundation, either version 3 of the License, or (at your
% option) any later version. This program is distributed in the hope that
% it will be useful, but without any warranty; without even the implied
% warranty of merchantability or fitness for a particular purpose. See the
% GNU General Public License <http://www.gnu.org/licenses/> for more details.

if (nargin < 2) || isempty(P2)
    P2 = 1e6;
end
if (nargin < 3) || isempty(alpha)
    alpha = 0.05;
end


% prepare plot window
fh = figure('Name', 'prevalence inference');
text(0.5, 0.5, {'please wait for results', '', ...
    'close window to stop computation at any time'}, 'HorizontalAlignment', 'center')
axis off
drawnow

% init
[n, N, P1] = size(a); % n: voxels, N: subjects, P1: first-level permutations
fprintf('\n*** performing permutation-based prevalence inference ***\n\n')
fprintf('generating %d of %d permutations\n', P2, P1 ^ N)
if P2 > P1 ^ N
    error('Monte Carlo is inadequate!')  % implement enumeration of permutations?
end
fprintf('the computation can be stopped at any time by closing the output window\n\n')
uRank = zeros(1, n);
cRank = zeros(1, n);

nPermsReport = 1;
tic
for j = 1 : P2
    % select first-level permutations
    if j == 1
        % select neutral permutations
        sp = ones(N, 1);
    else
        % select permutations randomly (Monte Carlo)
        sp = randi(P1, N, 1);
    end
    % indices of permutation values for each subject
    ind = sub2ind([N, P1], (1 : N)', sp);
    
    % test statistic: minimum across subjects
    m = min(a(:, ind)');                                                        %#ok<UDIM>
    % store result of neutral permutation, i.e. actual value, for each voxel
    if j == 1
        m1 = m;
    end
    
    % compare actual value with permutation value for each voxel separately;
    % determines uncorrected p-values for global null (see below)
    uRank = uRank + (m >= m1);          % Eq. 24
    % compare actual value at each voxel with maximum across voxels;
    % determines corrected p-values for global null (see below)
    cRank = cRank + (max(m) >= m1);     % Eq. 25 & 26

    % calibrate reporting interval to be between 5 and 12.5 seconds
    if (nPermsReport == 1) && (toc >= 5)
        nPermsReport = 10 ^ floor(log10(j)) * [1 2 5 10];
        nPermsReport = min(nPermsReport(nPermsReport >= j));
        nPermsReport = max(nPermsReport, 2);
    end
    
    % at intervals
    if ((nPermsReport > 1) && (mod(j, nPermsReport) == 0)) || (j == P2)
        drawnow
        stop = ~ishandle(fh);
        
        % compute results (following Step 5b)
        % based on permutations performed so far: j plays the role of P2
        
        % uncorrected p-values for global null hypothesis
        puGN = uRank / j;               % Eq. 24
        % corrected p-values for global null hypothesis
        pcGN = cRank / j;               % Eq. 25 & 26
        % corrected significance level for global null hypothesis
        alphac = (alpha - pcGN) ./ (1 - pcGN);
        % significant voxels for global null hypothesis
        sigGN = (puGN <= alphac);      % not necessarily the same as (pcGN <= alpha)!
        % lower bound for prevalence
        alphac(~sigGN) = nan;
        gamma0 = (alphac .^ (1/N) - puGN .^ (1/N)) ./ (1 - puGN .^ (1/N));
        % upper bound for lower bound
        alphacmax = (alpha - 1/j) / (1 - 1/j);
        gamma0max = (alphacmax .^ (1/N) - 1/j .^ (1/N)) ./ (1 - 1/j .^ (1/N));
        
        %         gamma0_c = 0.5;
        %         % uncorrected p-values for prevalence null hypothesis
        %         puPN = ((1 - gamma0_c) * puGN .^ (1/N) + gamma0_c) .^ N;
        %         % corrected p-values for prevalence null hypothesis
        %         pcPN = pcGN + (1 - pcGN) .* puPN;
        
        % print summary
        fprintf('  %d permutations  = %.1f %%  (%.1f of %.1f min)\n', ...
            j, j / P2 * 100, toc / 60, toc / 60 * P2 / j)
        fprintf('    minimal uncorrected rank: %d, reached at %d voxels\n', ...
            min(uRank), sum(uRank == min(uRank)))
        fprintf('    minimal corrected rank: %d, reached at %d voxels\n', ...
            min(cRank), sum(cRank == min(cRank)))
        fprintf('    minimal uncorrected p-value for global null: %g\n', ...
            min(puGN))
        fprintf('    minimal corrected p-value for global null: %g\n', ...
            min(pcGN))
        fprintf('    significant voxels for global null: %d\n', sum(sigGN))
        fprintf('    significant voxels for global null: %d\n', sum(pcGN <= alpha))
        fprintf('    maximal prevalence: %g\n', max(gamma0))
        fprintf('\n')
        
        % plot prevalence bounds
        if stop
            fh = figure('Name', 'prevalence inference');
        else
            figure(fh)
            clf
        end
        plot(gamma0, '.')
        title('prevalence inference')
        line([0.5, n + 0.5], gamma0max * [1 1], 'Color', 'k')
        axis([0.5, n + 0.5, 0, 1])
        xlabel('voxels')
        ylabel('\gamma_0')
        if n > 200
            set(gca, 'XTick', [])
        else
            set(gca, 'XTick', 1 : n)
            if n > 20
                set(gca, 'XTickLabel', [])
            end
        end
        drawnow

        if stop
            fprintf('computation stopped\n')
            break
        end
    end
    
end

% determine typical above-chance accuracies
n = size(a, 1);
at = nan(n, 1);
% where the majority show an effect, compute median
at(gamma0 >= 0.5) = median(a(gamma0 >= 0.5, :, 1), 2);

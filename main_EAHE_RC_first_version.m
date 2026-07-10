% Deprecated compatibility entry point.
% The original first-version script did not include the corrected
% undisturbed-soil annual phase alignment. Use the maintained model entry
% points instead.

warning(['main_EAHE_RC_first_version.m is deprecated. ', ...
    'Running main_baseline with the current model revision instead.']);

main_baseline;

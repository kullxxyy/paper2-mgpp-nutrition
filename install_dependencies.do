*===============================================================================
* PAPER 2 — OPTIONAL ONE-TIME DEPENDENCY INSTALLATION
* Run manually in Stata with internet access: do install_dependencies.do
* main.do only checks dependencies; it does not install packages automatically.
*===============================================================================
ssc install ftools, replace
ssc install reghdfe, replace
ssc install winsor2, replace
ssc install estout, replace
* Required only when P2_RUN_EVENTDD=1:
* ssc install eventdd, replace

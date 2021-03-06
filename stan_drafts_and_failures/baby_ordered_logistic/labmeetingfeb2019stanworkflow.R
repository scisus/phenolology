# Analysis for lab meeting - Prince George data

library(rstan)
library(bayesplot)
rstan_options(auto_write = TRUE)
options(mc.cores = parallel::detectCores())

util <- new.env()
source('~/Documents/classes/STANworkshop/material/1 - workflow/stan_utility.R', local=util)

# read in data ------------------------
phenologyheatsum_data <- read.csv('data/phenology_heatsum.csv')

phd <- phenologyheatsum_data

mphd <- subset(phd, Sex == "MALE") # separate out male and female datasets
fphd <- subset(phd, Sex == "FEMALE")

# tell stan about data ----------------------------

make_stan_data <- function(dataframe, filename) {
    N <- nrow(dataframe)
    K <- length(unique(dataframe$Phenophase_Derived))
    heatsum <- dataframe$Heatsum
    phenophase <- dataframe$Phenophase_Derived
    stan_rdump(c("N", "K", "heatsum", "phenophase"), file=filename)
}

make_stan_data(mphd, "data/stan_input/male_prince_george.data.R")
make_stan_data(fphd, "data/stan_input/female_prince_george.data.R")


mdstan <- read_rdump("data/stan_input/male_prince_george.data.R") #male data for stan
fdstan <- read_rdump("data/stan_input/female_prince_george.data.R") #female

# MALE FIT #######################################

mfit <- stan(file='phenology.stan', data=mdstan,
                iter=10000, warmup=1000, chains=5)

util$check_all_diagnostics(mfit)

show(mfit)
print(mfit)
plot(mfit)
summary(mfit)
get_posterior_mean(mfit)

# VISUAL MCMC DIAGNOSTICS ###########################

params <- extract(mfit)
posterior_cp <- as.array(mfit) #extract posterior draws
lp_cp <- log_posterior(mfit)

np_cp <- nuts_params(mfit) #nuts params
head(np_cp)

color_scheme_set("darkgray")
mcmc_parcoord(posterior_cp, np = np_cp) # parallel coordinates plot. show one line per iteration, connecting the parameter values at this iteration, with divergences in red. let's you see global patterns in divergences

mcmc_pairs(posterior_cp, np = np_cp, pars = c("beta", "c[1]", "c[2]")) # show univariate histograms and bivariate scatter plots for selected parameters and is especially useful in identifying collinearity between variables (which manifests as narrow bivariate plots) as well as the presence of multiplicative non-identifiabilities (bananas). Each bivariate plot occurs twice and contains half the chains - so you can compare if chains produce similar results

scatter_c1_cp <- mcmc_scatter( # investigate a single bivariate plot to investigate it more closely. plot centered parameterization
    posterior_cp,
    pars = c("c[1]", "beta"),
    transformations = list(beta = "log"),
    np = np_cp
)

scatter_c1_cp

mcmc_trace(posterior_cp, np=np_cp) #trace plot. time series plot of markov chains. use window argument to zoom in on suspicious sections.

color_scheme_set("red")
mcmc_nuts_divergence(np_cp, lp_cp) # understand how divergences interact with the model globally. Identify light tails and incomplete exploration of target distribution. use chain argument to overlay the plot for a particular Markov chain on the plot

color_scheme_set("red")
mcmc_nuts_energy(np_cp)
# energy plot. shows overlaid histograms of the (centered) marginal energy distribution piE and the first-differenced distribution pi_deltaE. id overly heavy tails (also challenging for sampling). the energy diagnostic for HMC (and the related energy-based Bayesian fraction of missing info) quantifies the heaviness of the tails of the posterior. Ideally the two histograms will look the same

# MCMC diagnostics: convergence?

# Rhat: potential scale reduction statistic
# compare a chain's behavior to other randomly intialized chains. Split R_hat measures ratio of the average variance of draws within each chain to the variance of the pooled draws across chains. If all chains at equilibrium, 1. If they haven't converged, > 1.

rhats <- rhat(mfit)
color_scheme_set("brightblue")
mcmc_rhat(rhats) +
    yaxis_text(hjust = 1)

# Effective sample size
# estimate of the number of independent draws from the posterior dist of the estimand of interest. n_eff in stan is based on ability of draws to estimate the true mean value of the param. because draws are not independent if there is autocorrelation between draws, neff is usually smaller than total N. the larger the ration of n_eff to N, the better. ratios depend not just on the model but on the algorithm used to fit the model

ratios_cp <- neff_ratio(mfit)
print(ratios_cp)

mcmc_neff(ratios_cp, size = 2) +
    yaxis_text(hjust = 1)

# Autocorrelation
#n_eff/N decreases as autocorrelation becomes more extreme. Visualize autocorrelation using mcmc_acf or mcmc_acf_bar. Postive autocorrelation is bad because it means the chain gets stuck. Ideally, it drops quickly to zero as lag increasses. negative autocorrelation indicates fast convergence of sample mean towards true

mcmc_acf(posterior_cp, lags = 10)

# PARAMETER ESTIMATES
############################################################
# PLOTTING MCMC DRAWS ####################################

posterior <- as.array(mfit)
dim(mfit)

dimnames(posterior)

### Posterior uncertainty intervals ("credible intervals")

# central posterior uncertainty intervals. by default shows 50% intervals (thick) and 90% intervals (thinner outer). Use point_est to show or hide point estimates
color_scheme_set("red")
mcmc_intervals(posterior, pars = c("c[1]", "c[2]", "beta"))

# show uncertainty intervals as shaded areas under estimated posterior density curves

mcmc_areas(
    posterior,
    pars = c("c[1]", "c[2]", "beta"),
    prob = 0.8, # 80% intervals
    prob_outer = 0.99, # 99% intervals
    point_est = "mean"
)

### Univariate marginal posterior distributions
# Look at histograms or kernel density estimates of marginal posterior distributions, chains together or separate

# plot marginal posterior distributions combining all chains. Tranformations argument can be helpful
color_scheme_set("green")
mcmc_hist(posterior, pars = c("c[1]", "c[2]", "beta"))

color_scheme_set("brightblue")
mcmc_hist_by_chain(posterior, pars = c("c[1]", "c[2]", "beta"))

# plot densities rather than histograms
color_scheme_set("purple")
mcmc_dens(posterior, pars = c("c[1]", "c[2]", "beta"))
# by chain
mcmc_dens_overlay(posterior, pars = c("c[1]", "c[2]", "beta"))

# plot violins

color_scheme_set("teal")
mcmc_violin(posterior, pars = c("c[1]", "c[2]", "beta"), probs = c(0.1, 0.5, 0.9))

### Bivariate plots

# just a scatterplot of two params
color_scheme_set("gray")
mcmc_scatter(posterior, pars = c("c[1]", "c[2]"))
mcmc_scatter(posterior, pars = c("c[1]", "beta"))
mcmc_scatter(posterior, pars = c("c[2]", "beta"))

# hexagonal binner helps avoid overplotting
mcmc_hex(posterior, pars = c("c[1]", "c[2]"))
mcmc_hex(posterior, pars = c("c[1]", "beta"))
mcmc_hex(posterior, pars = c("c[2]", "beta"))

# with more than two params. use hex plots instead with off_diag_fun = "hex". half markov chains above and half below diagonal
color_scheme_set("pink")
mcmc_pairs(posterior, pars = c("c[1]", "c[2]", "beta"), off_diag_args = list(size = 1.5))

### Trace plots
# no divergence info (see mcmc diagnostics graphs)

color_scheme_set("blue")
mcmc_trace(posterior, pars = c("c[1]", "c[2]", "beta"))

# with mixed colour scheme

color_scheme_set("mix-blue-red")
mcmc_trace(posterior, pars = c("c[1]", "c[2]", "beta"),
           facet_args = list(ncol=1, strip.position = "left")) #facet_arg passes parameters to facet_wrap in ggplot2. ncol puts traceplots in a column instead of side by side and strip.position moves the facet labels

# with viridis colour scheme
color_scheme_set("viridis")
mcmc_trace(posterior, pars = c("c[1]", "c[2]", "beta"))

# use points instead of lines and highlight a single chain
mcmc_trace_highlight(posterior, pars = c("c[1]", "c[2]", "beta"), highlight = 3)







# POSTERIOR PREDICTIVE CHECKS ##################################
# create graphical displays comparing observed data to simulated data
# if a model is a good fit than we should be able to use it to generate data that looks like the data we observed. to generate this data, we simulate from the posterior predictive distribution - distribution of the outcome variable implied by a model after using the observed data to update our beliefs about unknown model parameters

y <- mphd$Phenophase_Derived


# FEMALE FIT ############################################


ffit <- stan(file='phenology.stan', data=fdstan,
             iter=10000, warmup=1000, chains=5)

util$check_all_diagnostics(ffit)

# VISUAL MCMC DIAGNOSTICS ###########################

params <- extract(ffit)
posterior_cp <- as.array(ffit) #extract posterior draws
lp_cp <- log_posterior(ffit)

np_cp <- nuts_params(ffit) #nuts params
head(np_cp)

color_scheme_set("darkgray")
mcmc_parcoord(posterior_cp, np = np_cp) # parallel coordinates plot. show one line per iteration, connecting the parameter values at this iteration, with divergences in red. let's you see global patterns in divergences

mcmc_pairs(posterior_cp, np = np_cp, pars = c("beta", "c[1]", "c[2]")) # show univariate histograms and bivariate scatter plots for selected parameters and is especially useful in identifying collinearity between variables (which manifests as narrow bivariate plots) as well as the presence of multiplicative non-identifiabilities (bananas). Each bivariate plot occurs twice and contains half the chains - so you can compare if chains produce similar results

scatter_c1_cp <- mcmc_scatter( # investigate a single bivariate plot to investigate it more closely. plot centered parameterization
    posterior_cp,
    pars = c("c[1]", "beta"),
    transformations = list(beta = "log"),
    np = np_cp
)

scatter_c1_cp

mcmc_trace(posterior_cp, np=np_cp) #trace plot. time series plot of markov chains. use window argument to zoom in on suspicious sections.

color_scheme_set("red")
mcmc_nuts_divergence(np_cp, lp_cp) # understand how divergences interact with the model globally. Identify light tails and incomplete exploration of target distribution. use chain argument to overlay the plot for a particular Markov chain on the plot

color_scheme_set("red")
mcmc_nuts_energy(np_cp)
# energy plot. shows overlaid histograms of the (centered) marginal energy distribution piE and the first-differenced distribution pi_deltaE. id overly heavy tails (also challenging for sampling). the energy diagnostic for HMC (and the related energy-based Bayesian fraction of missing info) quantifies the heaviness of the tails of the posterior. Ideally the two histograms will look the same

# MCMC diagnostics: convergence?

# Rhat: potential scale reduction statistic
# compare a chain's behavior to other randomly intialized chains. Split R_hat measures ratio of the average variance of draws within each chain to the variance of the pooled draws across chains. If all chains at equilibrium, 1. If they haven't converged, > 1.

rhats <- rhat(ffit)
color_scheme_set("brightblue")
mcmc_rhat(rhats) +
    yaxis_text(hjust = 1)

# Effective sample size
# estimate of the number of independent draws from the posterior dist of the estimand of interest. n_eff in stan is based on ability of draws to estimate the true mean value of the param. because draws are not independent if there is autocorrelation between draws, neff is usually smaller than total N. the larger the ration of n_eff to N, the better. ratios depend not just on the model but on the algorithm used to fit the model

ratios_cp <- neff_ratio(ffit)
print(ratios_cp)

mcmc_neff(ratios_cp, size = 2) +
    yaxis_text(hjust = 1)

# Autocorrelation
#n_eff/N decreases as autocorrelation becomes more extreme. Visualize autocorrelation using mcmc_acf or mcmc_acf_bar. Postive autocorrelation is bad because it means the chain gets stuck. Ideally, it drops quickly to zero as lag increasses. negative autocorrelation indicates fast convergence of sample mean towards true

mcmc_acf(posterior_cp, lags = 10)

# PARAMETER ESTIMATES
############################################################
# Plotting MCMC draws ####################################

posterior <- as.array(ffit)
dim(ffit)

dimnames(posterior)

### Posterior uncertainty intervals ("credible intervals")

# central posterior uncertainty intervals. by default shows 50% intervals (thick) and 90% intervals (thinner outer). Use point_est to show or hide point estimates
color_scheme_set("red")
mcmc_intervals(posterior, pars = c("c[1]", "c[2]", "beta"))

# show uncertainty intervals as shaded areas under estimated posterior density curves

mcmc_areas(
    posterior,
    pars = c("c[1]", "c[2]", "beta"),
    prob = 0.8, # 80% intervals
    prob_outer = 0.99, # 99% intervals
    point_est = "mean"
)

### Univariate marginal posterior distributions
# Look at histograms or kernel density estimates of marginal posterior distributions, chains together or separate

# plot marginal posterior distributions combining all chains. Tranformations argument can be helpful
color_scheme_set("green")
mcmc_hist(posterior, pars = c("c[1]", "c[2]", "beta"))

color_scheme_set("brightblue")
mcmc_hist_by_chain(posterior, pars = c("c[1]", "c[2]", "beta"))

# plot densities rather than histograms
color_scheme_set("purple")
mcmc_dens(posterior, pars = c("c[1]", "c[2]", "beta"))
# by chain
mcmc_dens_overlay(posterior, pars = c("c[1]", "c[2]", "beta"))

# plot violins

color_scheme_set("teal")
mcmc_violin(posterior, pars = c("c[1]", "c[2]", "beta"), probs = c(0.1, 0.5, 0.9))

### Bivariate plots

# just a scatterplot of two params
color_scheme_set("gray")
mcmc_scatter(posterior, pars = c("c[1]", "c[2]"))
mcmc_scatter(posterior, pars = c("c[1]", "beta"))
mcmc_scatter(posterior, pars = c("c[2]", "beta"))

# hexagonal binner helps avoid overplotting
mcmc_hex(posterior, pars = c("c[1]", "c[2]"))
mcmc_hex(posterior, pars = c("c[1]", "beta"))
mcmc_hex(posterior, pars = c("c[2]", "beta"))

# with more than two params. use hex plots instead with off_diag_fun = "hex". half markov chains above and half below diagonal
color_scheme_set("pink")
mcmc_pairs(posterior, pars = c("c[1]", "c[2]", "beta"), off_diag_args = list(size = 1.5))

### Trace plots
# no divergence info (see mcmc diagnostics graphs)

color_scheme_set("blue")
mcmc_trace(posterior, pars = c("c[1]", "c[2]", "beta"))

# with mixed colour scheme

color_scheme_set("mix-blue-red")
mcmc_trace(posterior, pars = c("c[1]", "c[2]", "beta"),
           facet_args = list(ncol=1, strip.position = "left")) #facet_arg passes parameters to facet_wrap in ggplot2. ncol puts traceplots in a column instead of side by side and strip.position moves the facet labels

# with viridis colour scheme
color_scheme_set("viridis")
mcmc_trace(posterior, pars = c("c[1]", "c[2]", "beta"))

# use points instead of lines and highlight a single chain
mcmc_trace_highlight(posterior, pars = c("c[1]", "c[2]", "beta"), highlight = 3)





// Modified from Betancourt's case study https://betanalpha.github.io/assets/case_studies/ordinal_regression.html to add a covariate

functions {
  vector induced_dirichlet_rng(int K, real phi) {
    vector[K - 1] c;
    vector[K] p = dirichlet_rng(rep_vector(1, K));

    c[1] = phi - logit(1 - p[1]);
    for (k in 2:(K - 1))
      c[k] = phi - logit(inv_logit(phi - c[k - 1]) - p[k]);

    return c;
  }
}


transformed data {
  int<lower=1> N = 50; // Number of observations
  int<lower=1> K = 5;  // Number of ordinal categories
}

generated quantities {
  real beta = normal_rng(0,1); // covariate effect
  real x[N]; //simulate covariate
  vector[N] gamma; //simulated latent effect

  ordered[K - 1] c = induced_dirichlet_rng(K, 0); // (Internal) cut points
  int<lower=1, upper=K> y[N];                     // Simulated ordinals


  for (n in 1:N) {
    x[n] = normal_rng(0,1); // covariate
    gamma[n] = x[n] * beta; // Latent effect
  }

  for (n in 1:N) {
    y[n] = ordered_logistic_rng(gamma[n], c);
  }
}

##' Print Stan Diagnostics
##'
##' Retrieves the effect samples sizes and Rhats computed after a fitting function ran \code{rstan}, and prepares it for printing.  If the fit was created by \code{stackImpute}, the diagnostics for all imputations are printed (separately).
##' @title stanDx
##' @param object an object created by an \code{rms} package Bayesian fitting function such as \code{blrm} or \code{stackMI}
##' @return matrix suitable for printing
##' @examples
##' \dontrun{
##'   f <- blrm(...)
##'   stanDx(f)
##' }
##' @author Frank Harrell
stanDx <- function(object) {
  draws    <- object$draws
  n.impute <- object$n.impute
  if(! length(n.impute)) n.impute <- 1
  d <- object$diagnostics
  if(n.impute == 1 && (length(names(d)) == 1 && names(d) == 'pars')) {
    cat('Diagnostics failed trying to summarize', d$pars, '\n')
    return(invisible())
  }
  if(n.impute > 1) cat('Diagnostics for each of', n.impute, 'imputations\n\n')
	cat('Iterations:', object$iter, 'on each of', object$chains, 'chains, with',
			nrow(draws) / n.impute, 'posterior distribution samples saved\n\n')
	cat('For each parameter, n_eff is a crude measure of effective sample size',
			'and Rhat is the potential scale reduction factor on split chains',
			'(at convergence, Rhat=1)\n', sep='\n')
  if(n.impute == 1) {
    d[, 'n_eff']  <- round(d[, 'n_eff'])
    d[, 'Rhat']   <- round(d[, 'Rhat'], 3)
    rownames(d)   <- colnames(cbind(draws, object$omega))
    return(d)
  } else {
    D <- NULL
    for(i in 1 : n.impute) {
      dx <- d[[i]]
      dx[, 'n_eff']  <- round(dx[, 'n_eff'])
      dx[, 'Rhat' ]  <- round(dx[, 'Rhat'], 3)
      nams <- colnames(cbind(draws, object$omega))
      rownames(dx)   <- paste0(paste0('Imputation ', i, ': '), nams)
      D <- rbind(D, dx)
      }
  }
  D
}

##' Get Stan Output
##'
##' Extracts the object created by \code{rstan::sampling} so that standard Stan diagnostics can be run from it
##' @title stanGet
##' @param object an objected created by an \code{rms} package Bayesian fitting function
##' @return the object created by \code{rstan::sampling}
##' @examples
##' \dontrun{
##'   f <- blrm(...)
##'   s <- stanGet(f)
##' }
##' @author Frank Harrell
stanGet <- function(object) object$rstan

##' Extract Bayesian Summary of Coefficients
##'
##' Computes either the posterior mean (default), posterior median, or posterior mode of the parameters in an \code{rms} Bayesian regression model
##' @title coef.rmsb
##' @param object an object created by an \code{rms} package Bayesian fitting function
##' @param stat name of measure of posterior distribution central tendency to compute
##' @param ... ignored
##' @return a vector of intercepts and regresion coefficients
##' @examples
##' \dontrun{
##'   f <- blrm(...)
##'   coef(f, stat='mode')
##' }
##' @author Frank Harrell
coef.rmsb <- function(object, stat=c('mean', 'median', 'mode'), ...) {
	stat <- match.arg(stat)
	# pmode <- function(x) {
	# 	dens <- density(x)
	# 	dens$x[which.max(dens$y)[1]]
	# }
  getParamCoef(object, stat)
}

##' Variance-Covariance Matrix
##'
##' Computes the variance-covariance matrix from the posterior draws by compute the sample covariance matrix of the draws
##' @title vcov.rmsb
##' @param object an object produced by an \code{rms} package Bayesian fitting function
##' @param regcoef.only set to \code{FALSE} to also include non-regression coefficients such as shape/scale parameters
##' @param intercepts set to \code{'all'} to include all intercepts (the default), \code{'none'} to exclude them all, or a vector of integers to get selected intercepts
##' @param ... ignored
##' @return matrix
##' @examples
##' \dontrun{
##'   f <- blrm(...)
##'   v <- vcov(f)
##' }
##' @seealso [vcov.rms]
##' @author Frank Harrell
##' @md
vcov.rmsb <- function(object, regcoef.only=TRUE,
                      intercepts='all', ...) {
  
  ## Later will have to handle non-coefficient parameters

  if(length(intercepts) == 1 && is.character(intercepts) &&
     intercepts %nin% c('all', 'none'))
    stop('if character, intercepts must be "all" or "none"')

  draws <- object$draws
  
  if(! length(intercepts) ||
     (length(intercepts) == 1) && intercepts == 'all')
    return(var(draws))

  ns <- num.intercepts(object)
  p  <- ncol(draws)
  nx <- p - ns
  if(intercepts == 'none') intercepts <- integer(0)
  i <- if(nx == 0) intercepts else c(intercepts, (ns + 1) : p)
  var(draws[, i, drop=FALSE])
}

##' Basic Print for Bayesian Parameter Summary
##'
##' For a Bayesian regression fit prints the posterior mean, median, SE, highest posterior density interval, and symmetry coefficient from the posterior draws.  For a given parameter, the symmetry measure is computed using the \code{distSym} function.
##' @title print.rmsb
##' @param x an object created by an \code{rms} Bayesian fitting function
##' @param prob HPD interval coverage probability (default is 0.95)
##' @param dec amount of rounding (digits to the right of the decimal)
##' @param pr set to \code{FALSE} to return an unrounded matrix and not print
##' @param ... ignored
##' @return matrix (rounded if \code{pr=TRUE})
##' @examples
##' \dontrun{
##'   f <- blrm(...)
##'   print.rmsb(f)
##' }
##' @author Frank Harrell
print.rmsb <- function(x, prob=0.95, dec=4, pr=TRUE, ...) {
	s     <- x$draws
  param <- t(x$param)
  means <- param[, 'mean']
  colnames(param) <- upFirst(colnames(param))

	se <- sqrt(diag(var(s)))
	hpd <- apply(s, 2, HPDint, prob=prob)
  P   <- apply(s, 2, function(u) mean(u > 0))
	sym <- apply(s, 2, distSym)
	w <- cbind(param, SE=se, Lower=hpd[1,], Upper=hpd[2,], P, Symmetry=sym)
  rownames(w) <- names(means)
  if(! pr) return(w)
	cat(nrow(s), 'draws from the posterior distribution\n\n')
	round(w, dec)
}

##' Compile Stan Code
##'
##' Retrieves Stan code files from the github repository, compiles then with \code{rstan::stan_model}, and stores the compiled code in a central placed defined by the user with e.g. \code{options(stancompiled='~/R/stan')}.
##' stanCompile
##' @param mods character vector of base names of \code{.stan} model files to compile.  Default is to compile all those currently in use in \code{rms}
##' @param repo URL to online source file base
##' @examples
##'   \dontrun{
##'   options(stancompiled='~/R/stan')    # need this always
##'   stanCompile()    # do this once per computer to compile centrally
##'   }
##' @author Frank Harrell
stanCompile <-
  function(mods=c('lrm', 'lrmqr', 'lrmqrc', 'lrmqrcar1'),
           repo='https://raw.githubusercontent.com/harrelfe/stan/master') {
  requireNamespace('rstan', quietly=TRUE)
  options(auto_write = FALSE)
  stanloc <- .Options$stancompiled
  if(! length(stanloc)) stop('options(stancompiled=) not defined')

  cat('Compiling', length(mods), 'programs to', stanloc, '\n')
  for(m in mods) {
    cat('Compiling', m, '\n')
    f <- paste0(repo, '/', m, '.stan')
    w <- readLines(f)
    k <- rstan::stan_model(model_code = w)
    mod <- paste0(stanloc, '/', m, '.rds')
    saveRDS(k, mod)
  }
  invisible()
  }

##' Plot Posterior Densities and Summaries
##'
##' For an \code{rms} Bayesian fit object, plots posterior densities for selected parameters along with posterior mode, mean, median, and highest posterior density interval.  If the fit was produced by \code{stackMI} the density represents the distribution after stacking the posterior draws over imputations, and the per-imputation density is also drawn as pale curves.
##' @title plot.rmsb
##' @param x an \code{rms} Bayesian fit object
##' @param which names of parameters to plot, defaulting to all non-intercepts. Can instead be a vector of integers.
##' @param nrow number of rows of plots
##' @param ncol number of columns of plots
##' @param prob probability for HPD interval
##' @param ... passed to \code{ggplot2::geom_density}
##' @return \code{ggplot2} object
##' @author Frank Harrell
pw <- plot.rmsb <- function(x, which=NULL, nrow=NULL, ncol=NULL, prob=0.95, ...) {
  nrp      <- num.intercepts(x)
  draws    <- x$draws
  n.impute <- x$n.impute
  if(! length(n.impute)) n.impute <- 1
  omega <- x$omega
  est   <- x$param
  if(length(omega)) {
    draws <- cbind(draws, omega)
    g <- function(x) c(mode=NA, mean=mean(x), median=median(x))
    osummary <- apply(omega, 2, g)
    osummary <- osummary[rownames(est),, drop=FALSE]
    est      <- cbind(est, osummary)
    }
  nd    <- nrow(draws)
  nam   <- colnames(draws)
  if(! length(which)) which <- if(nrp == 0) nam else nam[-(1 : nrp)]
  if(! is.character(which)) which <- nam[which]
  draws <- draws[, which, drop=FALSE]
  
  hpd   <- apply(draws, 2, HPDint, prob=prob)
  # rownames(ci) <- c('Lower', 'Upper')
  
  draws  <- as.vector(draws)
  param  <- factor(rep(which, each=nd), which)
  imputation <- rep(rep(1 : n.impute, each = nd / n.impute), length(which))
  imputation <- paste('Imputation', imputation)

  est    <- est[, which, drop=FALSE]
  est    <- rbind(est, hpd)
  ne     <- nrow(est)
  stat   <- rownames(est)
  stat   <- ifelse(stat %in% c('Lower', 'Upper'),
                   paste(prob, 'HPDI'), stat)
  est    <- as.vector(est)
  eparam <- factor(rep(which, each=ne), which)
  stat   <- rep(stat, length(which))

  d  <- data.frame(param, draws,
                   imputation=if(n.impute > 1) imputation else 'Density',
                   sz=if(n.impute > 1) 0.2 else 1.4)
  if(n.impute > 1) {
    d2 <- d
    d2$imputation <- 'Stacked'
    d2$sz <- 1.4
    d <- rbind(d, d2)
  }

  de <- data.frame(param=eparam, est, stat)
  g <- ggplot(d, aes(x=draws, color=imputation, size=I(sz))) + geom_density() +
         geom_vline(data=de, aes(xintercept=est, color=stat, alpha=I(0.4))) +
         facet_wrap(~ param, scales='free', nrow=nrow, ncol=ncol) +
         guides(color=guide_legend(title='')) +
         xlab('') + ylab('')
  g
}

##' Diagnostic Trace Plots
##'
##' For an \code{rms} Bayesian fit object, uses by default the stored posterior draws to check convergence properties of posterior sampling.  If instead \code{rstan=TRUE}, calls the \code{rstan} \code{traceplot} function on the \code{rstan} object inside the \code{rmsb} object, to check properties of posterior sampling.  If \code{rstan=TRUE} and the \code{rstan} object has been removed and \code{previous=TRUE}, attempts to find an already existing plot created by a previous run of the \code{knitr} chunk, assuming it was the \code{plotno} numbered plot of the chunk.
##' @title stanDxplot
##' @param x an \code{rms} Bayesian fit object
##' @param which names of parameters to plot, defaulting to all non-intercepts.  When \code{rstan=FALSE} these are the friendly \code{rms} names, otherwise they are the \code{rstan} parameter names.  If the model fit was run through \code{stackMI} for multiple imputation, the number of traces is multiplied by the number of imputations.
##' @param rstan set to \code{TRUE} to use \code{rstan::traceplot} on a (presumed) stored \code{rstan} object in \code{x}, otherwise only real iterations are plotted and parameter values are shown as points instead of lines, with chains separated
##' @param previous see details
##' @param plotno see details
##' @param rev set to \code{TRUE} to reverse direction for faceting chains
##' @param stripsize specifies size of chain facet label text, default is 8
##' @param ... passed to \code{rstan::traceplot}
##' @return \code{ggplot2} object if \code{rstan} object was in \code{x}
##' @author Frank Harrell
stanDxplot <- function(x, which=NULL, rstan=FALSE, previous=TRUE,
                       plotno=1, rev=FALSE, stripsize=8, ...) {
  if(! rstan) {
    draws <- x$draws
    if(! length(which)) {
      nrp <- x$non.slopes
      which <- if(nrp > 0) colnames(draws)[-(1 : nrp)] else colnames(draws)
    }
    draws   <- cbind(draws, x$omega)
    draws   <- draws[, which, drop=FALSE]
    n.impute <- x$n.impute
    if(! length(n.impute)) n.impute <- 1
    nchains <- x$chains * n.impute
    ndraws  <- nrow(draws)
    chain   <- rep(rep(1 : nchains, each = ndraws / nchains), length(which))
    chain   <- paste('Chain', chain)
    draws   <- as.vector(draws)
    param   <- rep(which, each=ndraws)
    iter    <- rep(rep(1 : (ndraws / nchains), nchains), length(which))
    d       <- data.frame(chain, iter, param, draws)
    g <- ggplot(d, aes(x=iter, y=draws)) +
      geom_point(size=I(0.03), alpha=I(0.3)) +
      xlab('Post Burn-in Iteration') + ylab('Parameter Value') +
      theme(strip.text = element_text(size = stripsize))

    if(rev)  g <- g + facet_grid(chain ~ param, scales='free')
    else     g <- g + facet_grid(param ~ chain, scales='free_y')
    return(g)
    }

  if(! length(which)) which <- x$betas
  s <- x$rstan
  if(length(s)) return(rstan::traceplot(s, pars=which, ...))

  if(! previous)
    stop('fit did not have rstan information and you specified previous=FALSE')
  ## Assume that the plot was generated in a previous run before
  get   <- knitr::opts_current$get
  path  <- get('fig.path')
  cname <- get('label')
  dev   <- get('dev')
  if(! length(cname))
    stop('with no rstan component in fit and previous=TRUE you must call stanDxplot inside a knitr Rmarkdown chunk')
  file <- paste0(path, cname, '-', plotno, '.', dev)
  if(! file.exists(file))
    stop(paste('with no rstan component in fit, file', file, 'must exist when previous=TRUE'))
  knitr::include_graphics(file)
  }


##' Function Generator for Posterior Probabilities of Assertions
##'
##' From a Bayesian fit object such as that from \code{blrm} generates an R function for evaluating the probability that an assertion is true.  The probability, within simulation error, is the proportion of times the assertion is true over the posterior draws.  If the assertion does not evaluate to a logical or 0/1 quantity, it is taken as a continuous derived parameter and a posterior density for that parameter is drawn.
##' @title PostF
##' @param fit a Bayesian fit object
##' @param name specifies whether assertions will refer to shortened parameter names (the default) or original names.  Shorted names are of the form \code{a1, ..., ak} where \code{k} is the number of intercepts in the model, and \code{b1, ..., bp} where \code{p} is the number of non-intercepts.  When using original names that are not legal R variable names, you must enclose them in backticks.
##' @param pr set to \code{TRUE} to have a table of short names and original names printed when \code{name='short'}
##' @return an R function
##' @examples
##' \dontrun{
##'   f <- blrm(y ~ age + sex)
##'   P <- PostF(f)
##'   P(b2 > 0)     # Model is a1 + b1*age + b2*(sex == 'male')
##'   P(b1 < 0 & b2 > 0)   # Post prob of a compound assertion
##'   # To compute probabilities using original parameter names:
##'   P <- PostF(f, name='orig')
##'   P(age < 0)    # Post prob of negative age effect
##'   P(`sex=male` > 0)
##'   f <- blrm(y ~ sex + pol(age, 2))
##'   P <- PostF(f)
##'   # Compute posterior density of the vertex of the quadratic age effect
##'   P(-b2 / (2 * b3))
##' }
##' @author Frank Harrell
PostF <- function(fit, name=c('short', 'orig'), pr=FALSE) {
  name       <- match.arg(name)
  alphas     <- fit$alphas
  betas      <- fit$betas
  draws      <- fit$draws
  orig.names <- colnames(draws)
  if(name == 'short') {
    nrp <- num.intercepts(fit)
    rp  <- length(orig.names) - nrp
    nam <- c(if(nrp > 0) paste0('a', 1 : nrp),
             paste0('b', 1 : rp))
    if(pr) {
      w <- cbind('Original Name' = orig.names,
                 'Short Name'    = nam)
      rownames(w) <- rep('', nrow(w))
      print(w, quote=FALSE)
      }
    colnames(draws) <- nam
    }
  f <- function(assert, draws) {
    w <- eval(substitute(assert), draws)
    if(length(unique(w)) < 3) return(mean(w))
    ggplot(data.frame(w), aes(x=w)) + geom_density() +
      xlab(as.character(sys.call()[2])) + ylab('')
    }
  # Convert draws to data frame so eval() will work
  formals(f) <- list(assert=NULL, draws=as.data.frame(draws))
  f
}

## Test this approach:
#f <- function(assert, draws) eval(substitute(assert), draws)
#formals(f) <- list(assert=NULL, draws=list(a=1:5, b1=2:6, b3=3:7))
#f(a); f(b1); f(b2)   # with(draws, assert) did not work

# Help info is in rmsMisc.Rd since this is a non-exported function
getParamCoef <- function(fit, posterior.summary=c('mean', 'median', 'mode')) {
  posterior.summary <- match.arg(posterior.summary)
  param <- fit$param
  if(posterior.summary == 'mode' && 'mode' %nin% rownames(param))
    stop('posterior mode not included in model fit')
  param[posterior.summary, ]
}

##' Save Compact Version of rms Bayesian Fit
##'
##' Removes the \code{rstan} part a fit object and writes the fit object to the current working directory, with a \code{.rds} suffix, using \code{saveRDS}.
##' @title fitSave
##' @param fit fit object whose unquoted name becomes the base name of the \code{.rds} file
##' @param name suffix of file name to use if not the name of the first argument passed to \code{fitSave}
##' @author Frank Harrell
fitSave <- function(fit, name=as.character(substitute(fit))) {
  file <- paste0(name, '.rds')
  fit$rstan <- NULL
  saveRDS(fit, file, compress='xz')
  invisible()
}

##' Load a Saved rms Object
##'
##' Adds a suffix of \code{.rds} to the name of the argument and calls \code{readRDS} to read the stored object, returning it to the user
##' @title fitLoad
##' @param fit R object name (unquoted) that was passed to \code{fitSave}
##' @return an object, using an rms package fit object
##' @author Frank Harrell
fitLoad <- function(fit) {
  file <- paste0(as.character(substitute(fit)), '.rds')
  readRDS(file)
}

##' fitIf
##'
##' By calling \code{fitIf(fitname <- fitting_function(...))} \code{fitIf} determines whether the fit object has already been created under the file named \code{"fitname.rds"} in the current working directory, and if so loads it.  It also looks for a file with a name such as \code{"fitname-rstan.rds"} and if it exists laods it and adds that object as the \code{rstan} part of the model fit, for \code{rstan} diagnostics.  If the \code{"fitname.rds"} does not exist, runs the model fit, strips off the large \code{rstan} object, stores the short fit object in \code{"fitname.rds"} and stores the full fit object in R object \code{fitname} in the global environment.  To force a re-fit, remove the \code{.rds} object.
##' @title fitIf
##' @param w an expression of the form \code{fitname <- fitting_function(...)}
##' @author Frank Harrell
fitIf <- function(w) {
  x <- as.character(substitute(w))
  fitname <- x[2]   # left hand side of assignment
  file    <- paste0(fitname, '.rds')
  filers  <- paste0(fitname, '-rstan', '.rds')
  if(file.exists(file)) {
    fit <- readRDS(file)
    if(file.exists(filers)) {
      rs <- readRDS(filers)
      fit$rstan <- rs
    }
    assign(fitname, fit, envir=.GlobalEnv)
    return(invisible())    # note that w was never evaluated
    }
  fit <- w   # evaluates w (runs the fit) and assigns in .GlobalEnv
  fitsmall <- fit
  fitsmall$rstan <- NULL
  saveRDS(fitsmall, file, compress='xz')
  invisible()
}


##' Compare Bayesian Model Fits
##'
##' Uses \code{loo::loo_model_weights} to compare a series of models such as those created with \code{blrm}
##' @title compareBmods
##' @param ... a series of model fits
##' @param method see [loo::loo_model_weights]
##' @param r_eff_list see [loo::loo_model_weights]
##' @return a \code{loo::loo_model_weights} object
##' @author Frank Harrell
##' @md
compareBmods <- function(..., method='stacking', r_eff_list=NULL) {
  fits <- list(...)
  lo   <- lapply(fits, function(x) x$loo)
  loo::loo_model_weights(lo, method=method, r_eff_list=r_eff_list)
  }

##' Highest Posterior Density Interval
##'
##' Adapts code from \code{coda::HPDinterval} to compute a highest posterior density interval from posterior samples for a single parameter.  Quoting from the \code{coda} help file, for each parameter the interval is constructed from the empirical cdf of the sample as the shortest interval  for  which  the  difference  in  the  ecdf  values  of  the  endpoints  is  the  nominal  probability.  Assuming that the distribution is not severely multimodal, this is the HPD interval.
##' @title HPDint 
##' @param x a vector of posterior draws
##' @param prob desired probability coverage
##' @return a 2-vector with elements \code{Lower} and \code{Upper}
##' @author Douglas Bates and Frank Harrell
HPDint <- function(x, prob = 0.95) {
  x     <- sort(x)
  nsamp <- length(x)
  gap   <- max(1, min(nsamp - 1, round(nsamp * prob)))
  init  <- 1:(nsamp - gap)
  inds  <- which.min(x[init + gap] - x[init])
  c(Lower =  x[inds], Upper = x[inds + gap])
}

##' Distribution Symmetry Measure
##'
##' From a sample from a distribution computes a symmetry measure.  By default it is the gap between the mean and the 0.95 quantile divided by the gap between the 0.05 quantile and the mean.
##' @title distSym
##' @param x a numeric vector representing a sample from a continuous distribution
##' @param prob quantile interval coverage
##' @param na.rm set to \code{TRUE} to remove \code{NA}s before proceeding.
##' @return a scalar with a value of 1.0 indicating symmetry
##' @author Frank Harrell
distSym <- function(x, prob=0.9, na.rm=FALSE) {
  if(na.rm) x <- x[! is.na(x)]
  a <- (1. - prob) / 2.
  w <- quantile(x, probs=c(a / 2., 1. - a / 2.))
  xbar <- mean(x)
  (w[2] - xbar) / (xbar - w[1])
}

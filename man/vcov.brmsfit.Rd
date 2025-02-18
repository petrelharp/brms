% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/brmsfit-methods.R
\name{vcov.brmsfit}
\alias{vcov.brmsfit}
\title{Covariance and Correlation Matrix of Population-Level Effects}
\usage{
\method{vcov}{brmsfit}(object, correlation = FALSE, pars = NULL, ...)
}
\arguments{
\item{object}{An object of class \code{brmsfit}.}

\item{correlation}{Logical; if \code{FALSE} (the default), compute 
the covariance matrix, if \code{TRUE}, compute the correlation matrix.}

\item{pars}{Optional names of coefficients to extract.
By default, all coefficients are extracted.}

\item{...}{Currently ignored.}
}
\value{
covariance or correlation matrix of population-level parameters
}
\description{
Get a point estimate of the covariance or 
correlation matrix of population-level parameters
}
\details{
Estimates are obtained by calculating the maximum likelihood 
  covariances (correlations) of the posterior draws.
}
\examples{
\dontrun{
fit <- brm(count ~ zAge + zBase * Trt + (1+Trt|visit), 
           data = epilepsy, family = gaussian(), chains = 2)
vcov(fit)
}

}

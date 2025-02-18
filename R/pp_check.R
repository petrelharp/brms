#' Posterior Predictive Checks for \code{brmsfit} Objects
#' 
#' Perform posterior predictive checks with the help
#' of the \pkg{bayesplot} package.
#' 
#' @aliases pp_check
#' 
#' @param object An object of class \code{brmsfit}.
#' @param type Type of the ppc plot as given by a character string.
#'   See \code{\link[bayesplot:PPC-overview]{PPC}} for an overview
#'   of currently supported types. You may also use an invalid
#'   type (e.g. \code{type = "xyz"}) to get a list of supported 
#'   types in the resulting error message.
#' @param ndraws Positive integer indicating how many
#'  posterior draws should be used.
#'  If \code{NULL} all draws are used. If not specified,
#'  the number of posterior draws is chosen automatically.
#'  Ignored if \code{draw_ids} is not \code{NULL}.
#' @param group Optional name of a factor variable in the model
#'  by which to stratify the ppc plot. This argument is required for
#'  ppc \code{*_grouped} types and ignored otherwise.
#' @param x Optional name of a variable in the model. 
#'  Only used for ppc types having an \code{x} argument 
#'  and ignored otherwise.
#' @param ... Further arguments passed to \code{\link{predict.brmsfit}}
#'   as well as to the PPC function specified in \code{type}.
#' @inheritParams prepare_predictions.brmsfit
#' 
#' @return A ggplot object that can be further
#'  customized using the \pkg{ggplot2} package.
#' 
#' @details For a detailed explanation of each of the ppc functions, 
#' see the \code{\link[bayesplot:PPC-overview]{PPC}} 
#' documentation of the \pkg{\link[bayesplot:bayesplot-package]{bayesplot}} 
#' package.
#' 
#' @examples
#' \dontrun{
#' fit <-  brm(count ~ zAge + zBase * Trt
#'             + (1|patient) + (1|obs),
#'             data = epilepsy, family = poisson())
#' 
#' pp_check(fit)  # shows dens_overlay plot by default
#' pp_check(fit, type = "error_hist", ndraws = 11)
#' pp_check(fit, type = "scatter_avg", ndraws = 100)
#' pp_check(fit, type = "stat_2d")
#' pp_check(fit, type = "rootogram")
#' pp_check(fit, type = "loo_pit")
#' 
#' ## get an overview of all valid types
#' pp_check(fit, type = "xyz")
#' }
#' 
#' @importFrom bayesplot pp_check
#' @export pp_check
#' @export
pp_check.brmsfit <- function(object, type, ndraws = NULL, nsamples = NULL,
                             group = NULL, x = NULL, newdata = NULL,
                             resp = NULL, draw_ids = NULL, subset = NULL, ...) {
  dots <- list(...)
  if (missing(type)) {
    type <- "dens_overlay"
  }
  type <- as_one_character(type)
  if (!is.null(group)) {
    group <- as_one_character(group)
  }
  if (!is.null(x)) {
    x <- as_one_character(x)
  }
  ndraws_given <- any(c("ndraws", "nsamples") %in% names(match.call()))
  ndraws <- use_alias(ndraws, nsamples)
  draw_ids <- use_alias(draw_ids, subset)
  resp <- validate_resp(resp, object, multiple = FALSE)
  valid_types <- as.character(bayesplot::available_ppc(""))
  valid_types <- sub("^ppc_", "", valid_types)
  if (!type %in% valid_types) {
    stop2("Type '", type, "' is not a valid ppc type. ", 
          "Valid types are:\n", collapse_comma(valid_types))
  }
  ppc_fun <- get(paste0("ppc_", type), asNamespace("bayesplot"))

  object <- restructure(object)
  stopifnot_resp(object, resp)
  family <- family(object, resp = resp)
  if (has_multicol(family)) {
    stop2("'pp_check' is not implemented for this family.")
  }
  valid_vars <- names(model.frame(object))
  if ("group" %in% names(formals(ppc_fun))) {
    if (is.null(group)) {
      stop2("Argument 'group' is required for ppc type '", type, "'.")
    }
    if (!group %in% valid_vars) {
      stop2("Variable '", group, "' could not be found in the data.")
    }
  }
  if ("x" %in% names(formals(ppc_fun))) {
    if (!is.null(x) && !x %in% valid_vars) {
      stop2("Variable '", x, "' could not be found in the data.")
    }
  }
  if (type == "error_binned") {
    if (is_polytomous(family)) {
      stop2("Type '", type, "' is not available for polytomous models.")
    }
    method <- "posterior_epred"
  } else {
    method <- "posterior_predict"
  }
  if (!ndraws_given) {
    aps_types <- c(
      "error_scatter_avg", "error_scatter_avg_vs_x",
      "intervals", "intervals_grouped", "loo_pit", 
      "loo_intervals", "loo_ribbon", "ribbon", 
      "ribbon_grouped", "rootogram", "scatter_avg", 
      "scatter_avg_grouped", "stat", "stat_2d", 
      "stat_freqpoly_grouped", "stat_grouped", 
      "violin_grouped"
    )
    if (!is.null(draw_ids)) {
      ndraws <- NULL
    } else if (type %in% aps_types) {
      ndraws <- NULL
      message("Using all posterior draws for ppc type '", 
              type, "' by default.")
    } else {
      ndraws <- 10
      message("Using 10 posterior draws for ppc type '",
              type, "' by default.")
    }
  }
  
  y <- get_y(object, resp = resp, newdata = newdata, ...)
  draw_ids <- validate_draw_ids(object, draw_ids, ndraws)
  pred_args <- list(
    object, newdata = newdata, resp = resp, 
    draw_ids = draw_ids, ...
  )
  yrep <- do_call(method, pred_args)

  if (anyNA(y)) {
    warning2("NA responses are not shown in 'pp_check'.")
    take <- !is.na(y)
    y <- y[take]
    yrep <- yrep[, take, drop = FALSE]
  }
  
  data <- current_data(
    object, newdata = newdata, resp = resp, 
    re_formula = NA, check_response = TRUE, ...
  )
  # censored responses are misleading when displayed in pp_check
  bterms <- brmsterms(object$formula)
  cens <- get_cens(bterms, data, resp = resp)
  if (!is.null(cens)) {
    warning2("Censored responses are not shown in 'pp_check'.")
    take <- !cens
    if (!any(take)) {
      stop2("No non-censored responses found.")
    }
    y <- y[take]
    yrep <- yrep[, take, drop = FALSE]
  }
  # most ... arguments are ment for the prediction function
  for_pred <- names(dots) %in% names(formals(prepare_predictions.brmsfit))
  ppc_args <- c(list(y, yrep), dots[!for_pred])
  if ("psis_object" %in% setdiff(names(formals(ppc_fun)), names(ppc_args))) {
    ppc_args$psis_object <- do_call(
      compute_loo, c(pred_args, criterion = "psis")
    )
  }
  if ("lw" %in% setdiff(names(formals(ppc_fun)), names(ppc_args))) {
    ppc_args$lw <- weights(
      do_call(compute_loo, c(pred_args, criterion = "psis"))
    )
  }
  if (!is.null(group)) {
    ppc_args$group <- data[[group]]
  }
  if (!is.null(x)) {
    ppc_args$x <- data[[x]]
    if (!is_like_factor(ppc_args$x)) {
      ppc_args$x <- as.numeric(ppc_args$x)
    }
  }
  do_call(ppc_fun, ppc_args)
}

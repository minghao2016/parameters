#' Check suitability of data for Factor Analysis (FA)
#'
#' This checks whether the data is appropriate for Factor Analysis (FA) by running the \link[=check_sphericity]{Bartlett's Test of Sphericity} and the \link[=check_kmo]{Kaiser, Meyer, Olkin (KMO) Measure of Sampling Adequacy (MSA)}.
#'
#' @inheritParams check_kmo
#' @examples
#' library(parameters)
#'
#' check_factorstructure(mtcars)
#' @seealso check_kmo check_sphericity
#' @export
check_factorstructure <- function(x, ...) {
  check_sphericity(x, ...)
  check_kmo(x, ...)
}






#' Kaiser, Meyer, Olkin (KMO) Measure of Sampling Adequacy (MSA) for Factor Analysis
#'
#' Kaiser (1970) introduced a Measure of Sampling Adequacy (MSA), later modified by Kaiser and Rice (1974). The Kaiser-Meyer-Olkin (KMO) statistic, which can vary from 0 to 1, indicates the degree to which each variable in a set is predicted without error by the other variables.
#'
#' A value of 0 indicates that the sum of partial correlations is large relative to the sum correlations, indicating factor analysis is likely to be inappropriate. A KMO value close to 1 indicates that the sum of partial correlations is not large relative to the sum of correlations and so factor analysis should yield distinct and reliable factors.
#'
#' Kaiser (1975) suggested that KMO > .9 were marvelous, in the .80s, mertitourious, in the .70s, middling, in the .60s, medicore, in the 50s, miserable, and less than .5, unacceptable. Hair et al. (2006) suggest accepting a value > 0.5. Values between 0.5 and 0.7 are mediocre, and values between 0.7 and 0.8 are good.
#'
#'
#' @param x A dataframe.
#' @param ... Arguments passed to or from other methods.
#'
#' @examples
#' library(parameters)
#'
#' check_kmo(mtcars)
#' @author William Revelle (the psych package)
#'
#' @references \itemize{
#'   \item Kaiser, H. F. (1970). A second generation little jiffy. Psychometrika, 35(4), 401-415.
#'   \item Kaiser, H. F., \& Rice, J. (1974). Little jiffy, mark IV. Educational and psychological measurement, 34(1), 111-117.
#'   \item Kaiser, H. F. (1974). An index of factorial simplicity. Psychometrika, 39(1), 31-36.
#' }
#' @importFrom stats cov2cor
#' @export
check_kmo <- function(x, ...) {

  # This could be improved using the correlation package to use different correlation methods
  cormatrix <- cor(x, use = "pairwise.complete.obs", ...)
  Q <- solve(cormatrix)

  Q <- cov2cor(Q)
  diag(Q) <- 0
  diag(cormatrix) <- 0

  sumQ2 <- sum(Q^2)
  sumr2 <- sum(cormatrix^2)
  MSA <- sumr2 / (sumr2 + sumQ2)
  MSA_variable <- colSums(cormatrix^2) / (colSums(cormatrix^2) + colSums(Q^2))
  results <- list(MSA = MSA, MSA_variable = MSA_variable)

  if (MSA < 0.5) {
    insight::print_color(sprintf("Warning: Factor analysis is likely to be inappropriate (KMO = %.2f).", MSA), "red")
  } else {
    insight::print_color(sprintf("OK: The data seems appropriate for factor analysis (KMO = %.2f).", MSA), "green")
  }

  invisible(results)
}












#' Bartlett's Test of Sphericity
#'
#' Bartlett (1951) introduced the test of sphericity, which tests whether a matrix is significantly different from an identity matrix. This statistical test for the presence of correlations among variables, providing the statistical probability that the correlation matrix has significant correlations among at least some of variables. As for factor analysis to work, some relationships between variables are needed, thus, a significant Bartlett’s test of sphericity is required, say p < .001.
#'
#'
#' @param x A dataframe.
#' @param ... Arguments passed to or from other methods.
#'
#' @examples
#' library(parameters)
#'
#' check_sphericity(mtcars)
#' @author William Revelle (the psych package)
#'
#' @references Bartlett, M. S. (1951). The effect of standardization on a Chi-square approximation in factor analysis. Biometrika, 38(3/4), 337-344.
#'
#' @importFrom stats pchisq
#' @export
check_sphericity <- function(x, ...) {

  # This could be improved using the correlation package to use different correlation methods
  cormatrix <- cor(x, use = "pairwise.complete.obs", ...)

  n <- nrow(x)
  p <- dim(cormatrix)[2]

  detR <- det(cormatrix)
  statistic <- -log(detR) * (n - 1 - (2 * p + 5) / 6)
  df <- p * (p - 1) / 2
  pval <- pchisq(statistic, df, lower.tail = FALSE)

  results <- list(chisq = statistic, p = pval, dof = df)

  if (pval < 0.001) {
    insight::print_color(sprintf("OK: There is sufficient significant correlation in the data for factor analaysis (Chisq(%i) = %.2f, p = %.3f).", df, statistic, pval), "green")
  } else {
    insight::print_color(sprintf("Warning: There is not enough significant correlation in the data for factor analaysis (Chisq(%i) = %.2f, p = %.3f).", df, statistic, pval), "red")
  }

  invisible(results)
}
#' Parameter names formatting
#'
#' @param model A statistical model.
#'
#' @examples
#' library(parameters)
#'
#' model <- lm(Sepal.Length ~ Species * Sepal.Width, data = iris)
#' format_parameters(model)
#'
#' model <- lm(Sepal.Length ~ Species / Petal.Length, data = iris)
#' format_parameters(model)
#'
#' model <- lm(Sepal.Length ~ Petal.Length + (Species / Sepal.Width), data = iris)
#' format_parameters(model)
#'
#' model <- lm(Sepal.Length ~ Species + poly(Sepal.Width, 2), data = iris)
#' format_parameters(model)
#'
#' model <- lm(Sepal.Length ~ Species + poly(Sepal.Width, 2, raw = TRUE), data = iris)
#' format_parameters(model)
#' @return The formatted parameter names.
#' @importFrom utils tail head
#' @export
format_parameters <- function(model) {
  UseMethod("format_parameters")
}


#' @export
format_parameters.default <- function(model) {
  .format_parameter_default(model)
}


#' @export
format_parameters.glmm <- function(model) {
  .format_parameter_default(model, effects = "all")
}


#' @export
format_parameters.rma <- function(model) {
  params <- insight::find_parameters(model, flatten = TRUE)
  names(params) <- params
  params
}


#' @export
format_parameters.mira <- format_parameters.rma


#' @export
format_parameters.parameters_model <- function(model) {
  if (!is.null(attributes(model)$pretty_names)) {
    model$Parameter <- attributes(model)$pretty_names[model$Parameter]
  }
  model
}





# Utilities ---------------------------------------------------------------



.format_parameter_default <- function(model, effects = "fixed") {
  original_names <- names <- insight::find_parameters(model, effects = effects, flatten = TRUE)
  info <- insight::model_info(model, verbose = FALSE)

  ## TODO remove is.list() when insight 0.8.3 on CRAN
  if (is.null(info) || !is.list(info)) {
    info <- list(family = "unknown", link_function = "unknown")
  }

  # quick fix, for multivariate response models, we use
  # info from first model only
  if (insight::is_multivariate(model) && !"is_zero_inflated" %in% names(info)) {
    info <- info[[1]]
  }


  # special handling hurdle- and zeroinfl-models ---------------------
  if (isTRUE(info$is_zero_inflated) | isTRUE(info$is_hurdle)) {
    names <- gsub("^(count_|zero_)", "", names)
  }

  # special handling polr ---------------------
  if (inherits(model, "polr")) {
    original_names <- gsub("Intercept: ", "", original_names, fixed = TRUE)
    names <- gsub("Intercept: ", "", names, fixed = TRUE)
  }

  # special handling bracl ---------------------
  if (inherits(model, "bracl")) {
    names <- gsub("(.*):(.*)", "\\2", names)
  }

  # special handling DirichletRegModel ---------------------
  dirich_names <- NULL
  if (inherits(model, "DirichletRegModel")) {
    cf <- stats::coef(model)
    if (model$parametrization == "common") {
      pattern <- paste0("(", paste(model$varnames, collapse = "|"), ")\\.(.*)")
      dirich_names <- names <- gsub(pattern, "\\2", names(unlist(cf)))
    } else {
      dirich_names <- names <- gsub("(.*)\\.(.*)\\.(.*)", "\\3", names(unlist(cf)))
    }
    original_names <- names
  }


  # remove "as.factor()", "log()" etc. from parameter names
  names <- .clean_parameter_names(names)

  # Type-specific changes
  types <- parameters_type(model)
  if (is.null(types)) {
    return(NULL)
  }
  types$Parameter <- .clean_parameter_names(types$Parameter, full = TRUE)


  # hurdle- and zeroinfl-models
  if (isTRUE(info$is_zero_inflated) | isTRUE(info$is_hurdle)) {
    types$Parameter <- gsub("^(count_|zero_)", "", types$Parameter)
  }

  # special handling DirichletRegModel
  if (inherits(model, "DirichletRegModel") && !is.null(dirich_names)) {
    types$Parameter <- dirich_names
  }


  for (i in 1:nrow(types)) {
    name <- types$Parameter[i]

    # No interaction
    if (!types$Type[i] %in% c("interaction", "nested")) {
      type <- types[i, ]
      names[i] <- .format_parameter(name, variable = type$Variable, type = type$Type, level = type$Level)

      # Interaction or nesting
    } else {
      components <- unlist(strsplit(name, ":", fixed = TRUE))
      is_nested <- types$Type[i] %in% "nested"
      for (j in 1:length(components)) {
        if (components[j] %in% types$Parameter) {
          type <- types[types$Parameter == components[j], ]

          ## TODO check if this is ok...

          # for models with multiple response categories, we might have same
          # variable for each response, thus we have multiple rows here,
          # where only one row is required.

          if (nrow(type) > 1) type <- type[1, ]

          components[j] <- .format_parameter(components[j], variable = type$Variable, type = type$Type, level = type$Level)
        } else if (components[j] %in% types$Secondary_Parameter) {
          type <- types[!is.na(types$Secondary_Parameter) & types$Secondary_Parameter == components[j], ]
          components[j] <- .format_parameter(components[j], variable = type[1, ]$Secondary_Variable, type = type[1, ]$Secondary_Type, level = type[1, ]$Secondary_Level)
        }
      }
      names[i] <- .format_interaction(components, type = types[i, "Type"], is_nested = is_nested)
    }
  }

  # "types$Parameter" here is cleaned, i.e. patterns like "log()", "as.factor()"
  # etc. are removed. However, these patterns are needed in "parameters_table()",
  # code-line x$Parameter <- attributes(x)$pretty_names[x$Parameter]
  # when we use "types$Parameter" here, matching of pretty names does not work,
  # so output will be NA resp. blank fields... Thus, I think we should use
  # the original paramter-names here.

  names(names) <- original_names # types$Parameter
  names
}


#' @keywords internal
.format_parameter <- function(name, variable, type, level) {

  # Factors
  if (type == "factor") {
    name <- .format_factor(name = name, variable = variable)
  }

  # Polynomials
  if (type %in% c("poly", "poly_raw")) {
    name <- .format_poly(name = name, variable = variable, type = type, degree = level)
  }

  # Splines
  if (type == "spline") {
    name <- .format_poly(name = name, variable = variable, type = type, degree = level)
  }

  # log-transformation
  if (type == "logarithm") {
    name <- .format_log(name = name, variable = variable, type = type)
  }

  # exp-transformation
  if (type == "exponentiation") {
    name <- .format_log(name = name, variable = variable, type = type)
  }

  # log-transformation
  if (type == "squareroot") {
    name <- .format_log(name = name, variable = variable, type = type)
  }

  # As Is
  if (type == "asis") {
    name <- variable
  }

  # Smooth
  if (type == "smooth") {
    name <- gsub("^smooth_(.*)\\[(.*)\\]", "\\2", name)
    name <- gsub("s(", "Smooth term (", name, fixed = TRUE)
  }

  # Ordered
  if (type == "ordered") {
    name <- paste(variable, level)
  }

  name
}


#' @importFrom utils tail head
#' @keywords internal
.format_interaction <- function(components, type, is_nested = FALSE) {
  sep <- ifelse(is_nested, " : ", " * ")

  if (length(components) > 2) {
    if (type == "interaction") {
      components <- paste0("(", paste0(utils::head(components, -1), collapse = " * "), ")", sep, utils::tail(components, 1))
    } else {
      components <- paste0(components, collapse = sep)
    }
  } else {
    components <- paste0(components, collapse = sep)
  }
  components
}


#' @keywords internal
.format_factor <- function(name, variable) {
  level <- sub(variable, "", name)
  paste0(variable, " [", level, "]")
}

#' @keywords internal
.format_poly <- function(name, variable, type, degree) {
  paste0(variable, " [", format_order(as.numeric(degree), textual = FALSE), " degree]")
}

#' @keywords internal
.format_log <- function(name, variable, type) {
  paste0(variable, " [", gsub("(.*)\\((.*)\\)", "\\1", name), "]")
}

#' @keywords internal
.format_ordered <- function(degree) {
  switch(
    degree,
    ".L" = "[linear]",
    ".Q" = "[quadratic]",
    ".C" = "[cubic]",
    paste0("[", parameters::format_order(as.numeric(gsub("^", "", degree, fixed = TRUE)), textual = FALSE), " degree]")
  )
}

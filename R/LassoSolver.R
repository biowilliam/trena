#' Class LassoSolver
#'
#' @import glmnet
#' @include Solver.R
#' @import methods
#' 
#' @name LassoSolver-class

.LassoSolver <- setClass("LassoSolver",
                         contains="Solver",
                         slots = c(regulatorWeights="numeric",
                                   alpha = "numeric",
                                   lambda = "numeric",
                                   keep.metrics = "logical")
                         )
#----------------------------------------------------------------------------------------------------
#' Create a Solver class object using the LASSO solver
#'
#' @param mtx.assay An assay matrix of gene expression data
#' @param targetGene A designated target gene that should be part of the mtx.assay data
#' @param candidateRegulators The designated set of transcription factors that could be associated
#' with the target gene
#' @param regulatorWeights A set of weights on the transcription factors
#' (default = rep(1, length(tfs)))
#' @param alpha A parameter from 0-1 that determines the proportion of LASSO to ridge used in the
#' elastic net solver, with 0 being fully ridge and 1 being fully LASSO (default = 0.9)
#' @param lambda A tuning parameter that determines the severity of the penalty function imposed
#' on the elastic net regression. If unspecified, lambda will be determined via
#' permutation testing (default = numeric(0)).
#' @param keep.metrics A logical denoting whether or not to keep the initial supplied metrics
#' versus determining new ones
#' @param quiet A logical denoting whether or not the solver should print output
#'
#' @return A Solver class object with LASSO as the solver
#'
#' @seealso  \code{\link{solve.Lasso}}, \code{\link{getAssayData}}
#'
#' @family Solver class objects
#' 
#' @export
#' 
#' @examples
#' load(system.file(package="trena", "extdata/ampAD.154genes.mef2cTFs.278samples.RData"))
#' target.gene <- "MEF2C"
#' tfs <- setdiff(rownames(mtx.sub), target.gene)
#' lasso.solver <- LassoSolver(mtx.sub, target.gene, tfs)

LassoSolver <- function(mtx.assay=matrix(), targetGene, candidateRegulators,
                        regulatorWeights=rep(1, length(candidateRegulators)),
                        alpha = 0.9, lambda = numeric(0),
                        keep.metrics = FALSE, quiet=TRUE)
{
    if(any(grepl(targetGene, candidateRegulators)))
        candidateRegulators <- candidateRegulators[-grep(targetGene, candidateRegulators)]
    
    candidateRegulators <- intersect(candidateRegulators, rownames(mtx.assay))
    stopifnot(length(candidateRegulators) > 0)
    
    obj <- .LassoSolver(Solver(mtx.assay=mtx.assay,
                               quiet=quiet,
                               targetGene=targetGene,
                               candidateRegulators=candidateRegulators),
                        regulatorWeights=regulatorWeights,
                        alpha = alpha,
                        lambda = lambda,
                        keep.metrics = keep.metrics
                        )
    obj    
} # LassoSolver, the constructor
#----------------------------------------------------------------------------------------------------
#' Show the Lasso Solver
#' 
#' @rdname show.LassoSolver
#' @aliases show.LassoSolver
#'
#' @param object An object of the class LassoSolver
#'
#' @return A truncated view of the supplied object
#'
#' @examples
#' load(system.file(package="trena", "extdata/ampAD.154genes.mef2cTFs.278samples.RData"))
#' target.gene <- "MEF2C"
#' tfs <- setdiff(rownames(mtx.sub), target.gene)
#' lasso.solver <- LassoSolver(mtx.sub, target.gene, tfs)
#' show(lasso.solver)

setMethod('show', 'LassoSolver',
          
          function(object) {
              regulator.count <- length(getRegulators(object))
              if(regulator.count > 10){
                  regulatorString <- paste(getRegulators(object)[1:10], collapse=",")
                  regulatorString <- sprintf("%s...", regulatorString);
              }
              else
                  regulatorString <- paste(getRegulators(object), collapse=",")
              
              msg = sprintf("LassoSolver with mtx.assay (%d, %d), targetGene %s, %d candidate regulators %s, alpha = %f",
                            nrow(getAssayData(object)), ncol(getAssayData(object)),
                            getTarget(object), regulator.count, regulatorString, object@alpha)
              cat (msg, '\n', sep='')
          })
#----------------------------------------------------------------------------------------------------
#' Run the LASSO Solver
#'
#' @rdname solve.Lasso
#' @aliases run.LassoSolver solve.Lasso
#' 
#' @description Given a LassoSolver object, use the \code{\link{glmnet}} function
#' to estimate coefficients for each transcription factor as a predictor of the target gene's
#' expression level.
#'
#' @param obj An object of class LassoSolver
#'
#' @return A data frame containing the coefficients relating the target gene to each transcription factor, plus other fit parameters.
#'
#' @seealso \code{\link{glmnet}},, \code{\link{LassoSolver}}
#'
#' @family solver methods
#'
#' @examples
#' # Load included Alzheimer's data, create a TReNA object with LASSO as solver, and solve
#' load(system.file(package="trena", "extdata/ampAD.154genes.mef2cTFs.278samples.RData"))
#' target.gene <- "MEF2C"
#' tfs <- setdiff(rownames(mtx.sub), target.gene)
#' lasso.solver <- LassoSolver(mtx.sub, target.gene, tfs)
#' tbl <- run(lasso.solver)

setMethod("run", "LassoSolver",
          
          function (obj){
              
              mtx <- getAssayData(obj)
              target.gene <- getTarget(obj)
              tfs <- getRegulators(obj)
              
              mtx.beta <- .elasticNetSolver(obj, target.gene, tfs,
                                            obj@regulatorWeights,
                                            obj@alpha,
                                            obj@lambda,
                                            obj@keep.metrics)
              return(mtx.beta)
          })
#----------------------------------------------------------------------------------------------------

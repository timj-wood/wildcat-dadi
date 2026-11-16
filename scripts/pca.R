# PCA of the 46 cats in one MSMC multihetsep file, to check that the haplotype
# columns fall into the four groups listed in data/cat_orders.txt.
#
# Usage, from the repository root:
#
#     Rscript scripts/pca.R data/msmc_input_chr1.txt plots/chr1_pca.pdf

args <- commandArgs(trailingOnly = TRUE)
if (length(args) != 2) {
    stop("usage: Rscript scripts/pca.R <msmc_input.txt> <out.pdf>")
}
infile <- args[1]
outfile <- args[2]

msmc <- read.table(infile, as.is = TRUE)
align <- msmc[, 4]
nsites <- length(align)
nind <- nchar(align[1]) / 2

# Genotype matrix: 0 = homozygous for the major allele, 1 = heterozygous,
# 2 = homozygous for the minor allele. Individual i is haplotypes 2i-1 and 2i.
mymat <- matrix(nrow = nsites, ncol = nind)
intvec <- integer(nind)

for (j in seq_len(nsites)) {
    str1 <- unlist(strsplit(align[j], split = ""))
    tb1 <- table(str1)
    majtype <- names(which(tb1 == max(tb1)))
    if (length(majtype) > 1) majtype <- majtype[1]  # equal frequencies
    count <- 1
    for (k in seq(1, 2 * nind, by = 2)) {
        if (str1[k] == majtype && str1[k + 1] == majtype) {
            intvec[count] <- 0
        } else if (str1[k] != str1[k + 1]) {
            intvec[count] <- 1
        } else {
            intvec[count] <- 2
        }
        count <- count + 1
    }
    mymat[j, ] <- intvec
}

forpca <- t(mymat)
sdval <- apply(forpca, 2, sd)
wt <- sdval > 0.25
res1 <- prcomp(forpca[, wt], scale = TRUE)

# Group sizes follow the individual order in data/cat_orders.txt.
cvec <- c(rep(1, 16), rep(2, 10), rep(3, 6), rep(4, 14))

pdf(file = outfile)
plot(res1$x[, 1], res1$x[, 2], xlab = "PC 1", ylab = "PC 2", pch = 16, col = cvec)
legend(x = "topright", pch = 16, col = c(1, 2, 3, 4),
       legend = c("Scottish Wild", "Scottish Captive", "Domestic", "Continent Wild"))
dev.off()

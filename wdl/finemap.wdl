import "finemap_sub.wdl" as sub

task preprocess {
    String pheno
    String sumstats_pattern
    File sumstats = sub(sumstats_pattern,"\\{PHENO\\}",pheno)
    String zones
    String docker
    Int cpu
    Int mem
    Boolean scale_se_by_pval
    Boolean x_chromosome
    Boolean set_variant_id
    String rsid_col
    String chromosome_col
    String position_col
    String allele1_col
    String allele2_col
    String freq_col
    String beta_col
    String se_col
    String p_col
    String delimiter
    Int window
    Int max_region_width
    Float window_shrink_ratio
    # can be helpful if adding finemapping with relaxed threshold after more stringent has already ben run.
    # does not include regions with lead snp < this
    Float p_threshold
    Float? minimum_pval
    String? set_variant_id_map_chr

    command {

        make_finemap_inputs.py \
            --sumstats ${sumstats} \
            --rsid-col "${rsid_col}" \
            --chromosome-col "${chromosome_col}" \
            --position-col "${position_col}" \
            --allele1-col "${allele1_col}" \
            --allele2-col "${allele2_col}" \
            --freq-col "${freq_col}" \
            --beta-col "${beta_col}" \
            --se-col "${se_col}" \
            --p-col "${p_col}" \
            --delimiter "${delimiter}" \
            --grch38 \
            --exclude-MHC \
            --no-upload \
            --prefix ${pheno} \
            --out ${pheno} \
            --window ${window} \
            --max-region-width ${max_region_width} \
            --window-shrink-ratio ${window_shrink_ratio} \
            ${true='--scale-se-by-pval ' false=' ' scale_se_by_pval} \
            ${true='--x-chromosome' false=' ' x_chromosome} \
            ${true='--set-variant-id ' false=' ' set_variant_id} \
            ${true='--set-variant-id-map-chr ' false=' ' defined(set_variant_id_map_chr)}${set_variant_id_map_chr} \
            --p-threshold ${p_threshold} \
            ${true='--min-p-threshold ' false='' defined(minimum_pval)}${minimum_pval} \
            --wdl

            res=`cat ${pheno}_had_results`

            if [ "$res" == "False" ]; then
                touch ${pheno}".z"
                touch ${pheno}".lead_snps.txt"
                touch ${pheno}".lead_snps.txt"
                touch ${pheno}".bed"
            fi
    }

    output {

        Array[File] zfiles = glob("*.z")
        File leadsnps = pheno + ".lead_snps.txt"
        File bed = pheno + ".bed"
        File log = pheno + ".log"
        Boolean had_results = read_boolean("${pheno}_had_results")
    }

    runtime {
        docker: "${docker}"
        cpu: "${cpu}"
        memory: "${mem} GB"
        disks: "local-disk 20 HDD"
        zones: "${zones}"
        preemptible: 2
        noAddress: true
    }
}

workflow finemap {

    String zones
    String docker
    String sumstats_pattern
    File phenolistfile
    File phenotypes

    Array[String] phenos = read_lines(phenolistfile)
    String? set_variant_id_map_chr

    scatter (pheno in phenos) {

        call preprocess {
            input: zones=zones, docker=docker, pheno=pheno,
                sumstats_pattern=sumstats_pattern,set_variant_id_map_chr=set_variant_id_map_chr
        }

        if( preprocess.had_results) {
            call sub.ldstore_finemap {
                input: zones=zones, docker=docker, pheno=pheno, zfiles=preprocess.zfiles,
                    phenofile=phenotypes, pheno=pheno,set_variant_id_map_chr=set_variant_id_map_chr
            }
        }

    }

    output {
        Array[File] bed = preprocess.bed 
        Array[Boolean] had_results = preprocess.had_results
        Array[File] out_susie_snp_filtered = select_all(ldstore_finemap.out_susie_snp_filtered)
        Array[File] out_susie_cred_summary = select_all(ldstore_finemap.out_susie_cred_summary)
        Array[File] out_susie_snp_filtered_99 = select_all(ldstore_finemap.out_susie_snp_filtered_99)
        Array[File] out_susie_cred_summary_99 = select_all(ldstore_finemap.out_susie_cred_summary_99)
        Array[File] out_susie_snp_filtered_extend = select_all(ldstore_finemap.out_susie_snp_filtered_extend)
        Array[File] out_susie_cred_summary_extend = select_all(ldstore_finemap.out_susie_cred_summary_extend)
        Array[File] out_susie_snp = select_all(ldstore_finemap.out_susie_snp)
        Array[File] out_susie_snp_tbi = select_all(ldstore_finemap.out_susie_snp_tbi)
        Array[File] out_susie_cred = select_all(ldstore_finemap.out_susie_cred)
        Array[File] out_susie_cred_99 = select_all(ldstore_finemap.out_susie_cred_99)

        Array[Array[File]] out_susie_rds = select_all(ldstore_finemap.out_susie_rds)
        Array[Array[Array[File]]] out_finemap_cred_regions = select_all(ldstore.finemap_cred_regions)
        Array[File] out_finemap_snp = select_all(ldstore_finemap.out_finemap_snp)
        Array[File] out_finemap_snp_tbi = select_all(ldstore_finemap.out_finemap_snp_tbi)
        Array[File] out_finemap_config = select_all(ldstore_finemap.out_finemap_config)
        Array[File] out_finemap_region = select_all(ldstore_finemap.out_finemap_region)
    }
}

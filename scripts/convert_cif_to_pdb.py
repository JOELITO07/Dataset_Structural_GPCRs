import gemmi

doc = gemmi.cif.read_file("C:\\Users\\Usuario\\Downloads\\modbase-models.cif")

structure = gemmi.make_structure_from_block(doc.sole_block())

structure.write_pdb("celr3_human.pdb")
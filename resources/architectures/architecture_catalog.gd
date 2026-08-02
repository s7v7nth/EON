class_name ArchitectureCatalog
extends Resource
## Ordered list of selectable architectures for a run.

@export var architectures: Array[ArchitectureData] = []


func find_by_id(arch_id: GameplayEnums.ArchitectureId) -> ArchitectureData:
	for arch in architectures:
		if arch and arch.architecture_id == arch_id:
			return arch
	return null


func all() -> Array[ArchitectureData]:
	var result: Array[ArchitectureData] = []
	for arch in architectures:
		if arch:
			result.append(arch)
	return result

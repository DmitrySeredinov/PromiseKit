Pod::Spec.new do |s|
  s.name = "PromiseKit"
  s.version = "0"
  s.requires_arc = true
  s.preserve_paths = "macros.m", "NSMethodSignatureForBlock.m"
  s.source_files = "*.h", "PromiseKit*.m", "PromiseKit/*.h"
end

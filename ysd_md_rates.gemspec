Gem::Specification.new do |s|
  s.name    = "ysd_md_rates"
  s.version = "0.2.15"
  s.authors = ["Yurak Sisa Dream"]
  s.date    = "2014-10-06"
  s.email   = ["yurak.sisa.dream@gmail.com"]
  s.files   = Dir['lib/**/*.rb']
  s.summary = "A DattaMapper-based model for rates"
  
  s.add_runtime_dependency "data_mapper", "1.2.0"
  s.add_runtime_dependency "json"

  s.add_runtime_dependency "ysd_md_yito"
    
  s.add_development_dependency "rake"
  s.add_development_dependency "rspec"
  s.add_development_dependency "dm-sqlite-adapter" # Model testing using sqlite

end

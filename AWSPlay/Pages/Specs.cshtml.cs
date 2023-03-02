using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;
using Amazon.DynamoDBv2.DataModel;

namespace AWSPlay.Pages
{
    public class SpecsModel : PageModel
    {
        private readonly IDynamoDBContext _context;

        public List<Spec>? Specs { get; set; }

        [BindProperty]
        public string? NewSpec { get; set; }
        
        public SpecsModel(IDynamoDBContext context)
        {
            _context = context;
        }

        public async Task OnGet()
        {
            Specs = await _context.ScanAsync<Spec>(new ScanCondition[] { }).GetNextSetAsync();
        }

        public async Task<IActionResult> OnPostAsync()
        {
            if (!ModelState.IsValid || NewSpec == null)
            {
                return Page();
            }

            await _context.SaveAsync(new Spec { Id = Guid.NewGuid().ToString(), Value = NewSpec, Timestamp = DateTime.UtcNow.ToString("yyyyMMddHHmmss") });
            return RedirectToPage();
        }
    }

    [DynamoDBTable("awsplay")]
    public class Spec
    {
        [DynamoDBHashKey("id")]
        public string? Id { get; set; }
        [DynamoDBProperty("value")]
        public string? Value { get; set; }
        [DynamoDBProperty("timestamp")]
        public string? Timestamp { get; set; }
    }
}

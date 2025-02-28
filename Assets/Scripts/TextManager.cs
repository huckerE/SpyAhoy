using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using TMPro;
using UnityEngine.SceneManagement;

public class TextManager : MonoBehaviour
{
    public GameObject warningTextContainer;
    public TMP_Text warningText;
    public float delay;
    public string someText;

    // Start is called before the first frame update
    void Start()
    {
        
    }

    // Update is called once per frame
    void Update()
    {
        
    }

    public void Reveal()
    {
        warningTextContainer.SetActive(true);
        StartCoroutine(ChangeText());
    }

    IEnumerator ChangeText()
    {
        yield return new WaitForSeconds(delay);
        warningText.text = someText;
        StartCoroutine(LoadScene());
    }

    IEnumerator LoadScene()
    {
        yield return new WaitForSeconds(delay);
        SceneManager.LoadScene("Dungeon");
    }
}
